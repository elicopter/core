![Elicopter Core](logo.png)
=========

Elicopter Core aims to be a resilient and future proof flight controller.

> Note: Elicopter Core is still under heavy development.

## Build From Sources

* Define environment variable for custom Nerves System:

```
export NERVES_SYSTEM=*Path To Nerves System*
export NERVES_SYSTEM_CACHE=none
export NERVES_SYSTEM_COMPILER=local
```

* Build

```
cd apps/brain
mix deps.get
mix compile
```

## Develop

```
cd apps/brain
iex -S mix
```

## Release

* Configure your WIFI network:
```
export ELICOPTER_WIFI_SSID=*Your SSID*
export ELICOPTER_WIFI_PASSWORD=*Your Network Password*
```

> Note: WPA-PSK only.

### SDCard

* Build the firmware in *production* environment:
```
cd apps/brain
MIX_ENV=prod mix firmware
```

* Burn the image to an SD card:
```
mix firmware.burn
```

* Initialize the custom partition (4) file system:
```
mkfs.ext4 /dev/DEVICE4 -L DATA
```
> Note: DEVICE should be something like sda, sdb, ...

### Network Firmware Update

* Build and deploy the firmware directly through network:
```
MIX_ENV=prod mix firmware.upgrade
```

> Note: The flight controller needs to be already started and connected to the network.

## Contributing

Please read [CONTRIBUTING.md](https://github.com/elicopter/elicopter/blob/master/CONTRIBUTING.md) for details on our code of conduct, and the process for submitting pull requests to us.

## License

This project is licensed under the MIT License - see the [LICENSE.md](https://github.com/elicopter/elicopter/blob/master/LICENSE.md) file for details.
