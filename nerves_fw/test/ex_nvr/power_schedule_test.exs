defmodule ExNVR.Nerves.Monitoring.PowerScheduleTest do
  use ExNVR.DataCase, async: false

  import ExUnit.CaptureLog
  import Mimic

  alias ExNVR.Nerves.Monitoring.PowerSchedule
  alias ExNVR.Nerves.SystemSettings

  @moduletag :tmp_dir
  @moduletag capture_log: true

  # a schedule with no time intervals, the current time is always
  # outside of the schedule window
  @out_of_window_schedule %{"1" => []}

  setup :set_mimic_global
  setup :verify_on_exit!

  setup_all do
    Mimic.copy(NervesTime)
  end

  setup %{tmp_dir: tmp_dir} do
    Application.put_env(:ex_nvr_fw, :system_settings_path, Path.join(tmp_dir, "settings.json"))
    # use a short interval so re-armed checks fire during the test
    Application.put_env(:ex_nvr_fw, :power_schedule_check_interval, 50)
    on_exit(fn -> Application.delete_env(:ex_nvr_fw, :power_schedule_check_interval) end)

    # make system settings process pick the path
    # in the config above
    settings_pid = Process.whereis(SystemSettings)
    ref = Process.monitor(settings_pid)
    Process.exit(settings_pid, :kill)
    assert_receive {:DOWN, ^ref, :process, ^settings_pid, _reason}, 1_000
    wait_until_registered(SystemSettings)

    test_pid = self()

    stub(NervesTime, :synchronized?, fn ->
      send(test_pid, :schedule_checked)
      true
    end)

    :ok
  end

  test "schedule check is re-armed after :stop_recording action" do
    assert {:ok, _settings} =
             SystemSettings.update_power_schedule_settings(%{
               schedule: @out_of_window_schedule,
               timezone: "UTC",
               action: "stop_recording"
             })

    pid = start_link_supervised!({PowerSchedule, []})

    logs =
      capture_log(fn ->
        send(pid, :check_schedule)

        # the action should be triggered and a new check scheduled,
        # repeatedly
        for _i <- 1..3 do
          assert_receive :schedule_checked, 1_000
        end

        # The stub sends :schedule_checked from inside NervesTime.synchronized?/0,
        # which runs before the action and timer re-arm. Use a GenServer system
        # call as a barrier so capture_log sees the full check before asserting.
        :sys.get_state(pid)
      end)

    assert logs =~ "stopping all devices"
  end

  test "schedule check is re-armed when action is :nothing" do
    assert {:ok, _settings} =
             SystemSettings.update_power_schedule_settings(%{
               schedule: @out_of_window_schedule,
               timezone: "UTC",
               action: "nothing"
             })

    pid = start_link_supervised!({PowerSchedule, []})

    logs =
      capture_log(fn ->
        send(pid, :check_schedule)

        for _i <- 1..3 do
          assert_receive :schedule_checked, 1_000
        end

        # The stub sends :schedule_checked from inside NervesTime.synchronized?/0,
        # which runs before the action and timer re-arm. Use a GenServer system
        # call as a barrier so capture_log sees the full check before asserting.
        :sys.get_state(pid)
      end)

    refute logs =~ "unknown action"
  end

  defp wait_until_registered(name, retry \\ 100)

  defp wait_until_registered(name, 0) do
    raise "process #{inspect(name)} was not restarted"
  end

  defp wait_until_registered(name, retry) do
    unless Process.whereis(name) do
      Process.sleep(10)
      wait_until_registered(name, retry - 1)
    end

    :ok
  end
end
