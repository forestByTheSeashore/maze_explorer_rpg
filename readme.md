# ForestByTheSeashore - A Maze Explorer RPG (Work in Progress!)

Hey there! 👋 Welcome to the development repository for "ForestByTheSeashore" (working title!), my 2D top-down maze exploration RPG project, built with the awesome Godot Engine!

I'm passionate about creating a fun and challenging experience where players can get lost in procedurally generated mazes, battle cool enemies, and grow their character. This is a solo-dev journey, and I'm excited to share its progress.

## What's This Game About?

You're an adventurer (exploring) through an ever-changing maze. Your goal? To survive, get stronger, find the key, and make it to the exit of each level!

**Core Features I'm working on:**

* **Endless Mazes:** Thanks to a procedural generation algorithm (Recursive Backtracking, if you're curious!), every time you play a level, the layout will be different, offering fresh challenges.
* **Character Growth:**
  * **Level Up Your HP:** Defeat enemies to gain EXP. Rack up enough EXP, and your max HP increases! Your base attack power is also tied to your HP.
  * **Gear Up!:** Find different swords to boost your total attack power (Base Attack + Weapon Attack).
* **Loot & Collectibles:**
  * **HP Beans:** Munch on these to recover HP (or maybe even boost your max!).
  * **Swords of Varying Might:** Discover swords with different attack bonuses. Choose wisely!
  * **The Almighty Key:** You'll need this to unlock the exit door and escape the current maze.
* **Enemies & Combat:**
  * Face off against various foes with different attack strengths.
  * Combat is straightforward: if your total attack power is greater than the enemy's, you win the skirmish!
  * Watch out! Some enemies will chase you relentlessly if you get too close.
  * Enemy AI is powered by Finite State Machines (FSM) and A* pathfinding (thanks to Godot's Navigation2D).
* **Level Structure:**
  * Levels are designed to be challenging but fair, with a strategic placement of items and enemies. Check out the `documents/CodeDesign.md` for an example of Level 3's map and flow!
  * Built using Godot's TileMap system for that classic 2D feel.

## Tech Stack & Design Choices

* **Engine:** Godot Engine (because it's awesome for 2D and indie-friendly!)
* **Key Algorithms:**
  * Level Generation: Recursive Backtracking
  * Enemy AI: FSM & A* Pathfinding (via Navigation2D)
* **Some Design Patterns I'm Using:**
  * Singleton: For the `GameManager` to keep things tidy.
  * Observer: Leveraging Godot's built-in signals for clean communication between game parts.
  * State Pattern: To make enemy behaviors more modular and easier to manage.

## Getting Started / How to Run

(This is a placeholder - you'll want to fill this in with actual instructions!)

1. Make sure you have Godot Engine installed (I'm using version X.Y.Z - *specify your version*).
2. Open Godot, click "Import", and navigate to the cloned project folder. Select the `project.godot` file.
3. Once imported, hit F5 (or the "Play" button) to run the main scene! (Let me know which scene is the main one to run, e.g., `Main.tscn` or a specific level).

## Screenshots

*(This is a great place to put a cool screenshot or two of your game in action!)*

## AI Tool Usage

Just a heads-up, I've used some AI tools (like ChatGPT-4o) to help with background research, learning, and even generating some initial ideas for textures and art assets. You can find more details on the prompts and how I adapted the outputs in the `AI_Declaration.md` (or similar) file within the project docs.

## What's Next? (My Rough Roadmap)

* More enemy types with unique behaviors!
* A wider variety of items, maybe some consumables or passive buffs.
* Boss battles (thinking of designing).
* More complex maze features (traps, puzzles, special rooms?).
* Maybe a simple story to tie it all together!

## Feedback & Contributions

This is a personal project and a learning experience for me. If you happen to try it out or look through the code:

* **Feedback is gold!** If you have ideas, suggestions, or find any pesky bugs, feel free to open an Issue.
* **Contributions:** While I'm primarily developing this solo for now, I'm always open to hearing about cool ideas or approaches.

---

Thanks for checking out my project! Wish me luck! 😄
