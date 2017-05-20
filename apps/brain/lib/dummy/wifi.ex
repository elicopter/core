defmodule Brain.Dummy.InterimWifi do

  def setup(:wlan0, ssid: _ssid, key_mgmt: _key_mgmt, psk: _psk) do
    {:ok, "fake_pid"}
  end
end
