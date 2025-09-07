# FRP_MDTUI

FRP_MDTUI is a FiveM resource that provides an immersive Mobile Data Terminal (MDT) interface for QBCore-based roleplay servers. The UI delivers dispatch information, audio alerts, an ALPR system, and an automated speed enforcement window.

## Features
- Web-based MDT and dispatch interface served from the resource's `web` folder
- Integration with **qb-core**, **oxmysql**, and **lb-tablet**
- Configurable dispatch audio and professional police scanner sounds
- ALPR (Automatic License Plate Recognition) and Automated Speed Enforcement (ASE) interfaces
- Customizable open command and toggle key

## Requirements
- FiveM server
- `qb-core`
- `oxmysql`
- `lb-tablet`

## Installation
1. Place the `FRP_MDTUI` folder in your server's resources directory.
2. Ensure the required dependencies are installed and running.
3. Add `ensure FRP_MDTUI` to your `server.cfg`.

## Configuration
- `shared/config.lua` – adjust whitelisted jobs, open command, toggle key, allowed vehicles, and audio settings.
- `shared/audio_config.lua` – map dispatch events to audio files and control volumes/delays.

## Usage
- Open the MDT with `/computer` or press **F7** by default.
- Officers can toggle the Automated Speed Enforcement window with `/ase`.
- Various test commands exist for development (e.g., `/dispatchtest`, `/testall`, `/test_vehicle_info`).

## Contributing
Pull requests are welcome. Please ensure your code follows existing style and includes any relevant configuration updates.

## License
Specify your license here.

