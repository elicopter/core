# Elicopter Core [![Slack Status](https://elicopter-slackin.herokuapp.com/badge.svg)](https://elicopter-slackin.herokuapp.com/)

Embedded Elixir flight controller.

## Getting Started

Install dependencies:
```
mix deps.get
```

Run locally:
```
iex -S mix
```
  
Or burn the firmware for Rapsberry Pi 3:
```
MIX_ENV=prod mix firmware
```

Burn the image to an SD card:
```
mix firmware.burn
```

Insert the card to your Raspberry Pi 3 and enjoy :)

## Contributing

Please read [CONTRIBUTING.md](https://github.com/elicopter/elicopter/blob/master/CONTRIBUTING.md) for details on our code of conduct, and the process for submitting pull requests to us.

## Authors

* **Loic Vigneron** - [Spin42](https://github.com/spin42)
* **Marc Lainez** - [Spin42](https://github.com/spin42)
* **Thibault Poncelet** - [Spin42](https://github.com/spin42)
* **Who's next? :)**

## License

This project is licensed under the MIT License - see the [https://github.com/elicopter/elicopter/blob/master/LICENSE.md](LICENSE.md) file for details
