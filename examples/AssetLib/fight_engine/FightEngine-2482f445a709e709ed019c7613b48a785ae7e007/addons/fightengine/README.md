# Fight Engine
A comprehensive Godot 4.5 plugin for creating 2D fighting games with precision and ease.

## Overview
Fxll3n's Fight Engine (FFE) provides essential systems and tools for building 2D fighting games in Godot. Whether you're creating a traditional arcade fighter or a platform fighter, this plugin handles complex mechanics so you can focus on making your game unique.

## Features

### ✅ Implemented
- **Hit & Hurt Boxes** - Precise collision detection system for attacks and vulnerable areas
- **State Machine Integration** - Integrates [LimboAI](https://github.com/limbonaut/limboai) by [limbonaut](https://github.com/limbonaut) for robust character state management

> **Note**: This plugin uses LimboAI for state management because it provides excellent FSM functionality, supports NPC behavior trees, and offers better performance as a GDExtension (written in C++ rather than GDScript). LimboAI is licensed under the MIT License.

### 🚧 In Development
- **Frame Data System** - Define and manage frame-perfect timing for moves and animations
- **Input Buffer** - Queue and process inputs with frame-accurate timing
- **Combo System** - Track and validate combo strings
- **Special Move Detection** - Recognize directional input patterns (e.g., quarter-circles, dragon punches)

## Installation

### From Godot Asset Library (Recommended)
1. Open Godot and go to the AssetLib tab
2. Search for "Fight Engine"
3. Click Download and Install
4. Enable the plugin in Project → Project Settings → Plugins

### Manual Installation
1. Download the latest release from the [releases page](https://github.com/yourusername/fightengine/releases)
2. Extract the `addons/fightengine` folder into your project's `addons/` directory
3. Enable the plugin in Project → Project Settings → Plugins

## Requirements
- Godot 4.5 or higher
- [LimboAI plugin](https://github.com/limbonaut/limboai) (install separately or included in this package)
- Basic knowledge of Godot's node system and GDScript

## Quick Start
1. Enable the Fight Engine plugin in your project settings
2. Install LimboAI plugin if not already included
3. Open the demo project included in `addons/fightengine/demo/`
4. Explore the example fighter character setup

## Documentation
Full documentation is in development. For now:
- Check the example in `addons/fightengine/demo/`

## Roadmap
- [ ] Frame Data System
- [X] State Machine Integration
- [ ] Input Buffer
- [ ] Combo System
- [ ] Special Move Detection

## Dependencies
This plugin includes or requires:
- **LimboAI** by limbonaut - [MIT License](https://github.com/limbonaut/limboai/blob/master/LICENSE.md)

## License
This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Credits
- **State Machine**: Uses [LimboAI](https://github.com/limbonaut/limboai) by [limbonaut](https://github.com/limbonaut)
- **Fight Engine**: Created by Fxll3n

## Contributing
Contributions are welcome! Please feel free to submit a Pull Request.

## Support
- Report bugs on the [Issues page](https://github.com/yourusername/fightengine/issues)
- For questions, use the [Discussions tab](https://github.com/yourusername/fightengine/discussions)

## Changelog
See [CHANGELOG.md](CHANGELOG.md) for version history.
