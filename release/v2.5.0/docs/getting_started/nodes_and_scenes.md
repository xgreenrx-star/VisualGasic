# Nodes and Scenes

To create a game, you need these two core concepts: **Nodes** and **Scenes**.

## Nodes

A **Node** is the smallest building block of your game. A node:
-   Has a name.
-   Has editable properties (like position, visibility, or texture).
-   Can receive callbacks (like `_Ready`, `_Process`).
-   Can be extended with new functions.
-   Can be added to another node as a child.

In Visual Gasic mode, we manipulate these nodes using commands like `CreateActor2D` (which makes a `CharacterBody2D` node) or `CreateLabel`.

## Scenes

A **Scene** is a group of nodes organized in a tree structure. Use the Godot Editor to arrange nodes to create:
-   A Character (Sprite + Collision).
-   A Level (TileMap + Enemies).
-   A Main Menu (Labels + Buttons).

You can save scenes to disk (`.tscn`) and then instantiate them.

### Instantiating in Code

In Visual Gasic, you load scenes using `LoadForm`.

```bas
' Load a scene from disk and add it to the game
LoadForm "res://Player.tscn"
```

## The Scene Tree

All your scenes come together in the **Scene Tree**. Accessing nodes in the tree is essential for game logic.

```bas
' Accessing the Title node (if naming follows convention)
Dim label
Set label = GetNode("TitleLabel")
label.Text = "Welcome"
```
