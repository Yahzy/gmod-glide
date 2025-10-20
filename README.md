# Glide // Styled's Vehicle Base

A pack of content and entity classes to add cars, motorcycles and boats to Garry's Mod.

[![GLuaLint](https://github.com/StyledStrike/gmod-glide/actions/workflows/glualint.yml/badge.svg)](https://github.com/FPtje/GLuaFixer)
[![Workshop Page](https://img.shields.io/endpoint.svg?url=https%3A%2F%2Fshieldsio-steam-workshop.jross.me%2F3389728250%2Fsubscriptions-text)](https://steamcommunity.com/sharedfiles/filedetails/?id=3389728250)
[![Discord Server](https://img.shields.io/badge/Discord-Discord?style=flat&logo=discord&logoColor=white&color=5662F6)](https://discord.gg/aSecXvMXM2)

## Features

- Includes base classes for cars, motorcycles and boats
- Duplicator/Advanced Duplicator 2 support
- You can use the regular sandbox Color tool
- No constraints are used for wheel physics
- Comes with 7 cars, 3 motorcycles and 2 boats
- First person and GTA-like third person camera
- Vehicles can set custom player poses per seat
- Editable engine/transmission/traction properties for cars and motorcycles
- Car headlights, reverse lights, break lights, horns and sirens for emergency vehicles
- Separate chassis and engine health
- All vehicles can be controlled with Wiremod

### Player settings

- Camera sensitivity, distance, FOV, and auto-center
- 3 mouse input modes for flying: Point-to-aim (LFS), Control movement directly (WAC) and Free camera (GTA V)
- Custom key binds, manual gear shifting toggle
- Change the volume for land vehicles and explosions
- Change the volume of all Glide vehicles when someone is talking on voice chat
- Toggle headlight shadows, automatic headlights, and many others

### Tools

- Engine Stream
- Vehicle Material
- Wheel Model
- Water Driving

### Other features

- Many different wheel sounds for different surfaces
- Custom tags when looking at Glide vehicles
- Custom tags when looking at players while driving Glide vehicles
- Lots of optimizations (model LODs, client-side vehicle sounds/animations only play when they are near you, etc)
- Custom notifications system

## Server console variables

### Vehicle damage multipliers

| Command | Description
| ------- | -----------
| `glide_bullet_damage_multiplier` `<number>` | Damage multiplier for bullets hitting Glide vehicles
| `glide_blast_damage_multiplier` `<number>` | Damage multiplier for explosions hitting Glide vehicles
| `glide_physics_damage_multiplier` `<number>` | Damage multiplier taken by Glide vehicles after colliding against things that are not the world.
| `glide_world_physics_damage_multiplier` `<number>` | Damage multiplier taken by Glide vehicles after colliding against the world.
| `glide_global_damage_multiplier` `<number>` | Multiplier for damage taken from any source (except from collisions)

### Sandbox limits

| Command | Description
| ------- | -----------
| `sbox_maxglide_vehicles` `<number>` | Max. number of Glide vehicles that one player can have

## Contributing

Please follow the [these rules](https://github.com/StyledStrike/gmod-glide/blob/main/.github/pull_request_template.md) before opening pull requests.
