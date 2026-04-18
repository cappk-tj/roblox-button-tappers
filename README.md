# Button Tappers

An Incremental / Clicker game where players earn cash, buy upgrades, rebirth and progress.

### ⚙️ Tech
- Roblox Studio
- Luau

### ✨ Features
- **Cash System** — Players gain cash by clicking buttons with varying reward multipliers
- **Upgrades** — Players can purchase upgrades to increase their base click earnings
- **Multipliers** — Increase earnings through premium currency (Diamonds) or rebirthing
- **Rebirths** — Reset progress in exchange for permanent multipliers and faster future progression
- **Data Stores** — Player data saves across different sessions using Data Stores
- **UI Feedback** — Interactive UI responses for purchases, upgrades and other progression actions
- **Player Stats** — Tracks lifetime cash earned, join date, playtime and other progression metrics

### 🛠️ The Process
I used to play Cookie Clicker a lot so I thought it'd be fun to recreate that kind of game on Roblox! Basically Cookie Clicker, but in 3D with a bunch of extra features I added along the way. This project took around 6 months to complete and is easily the biggest and most polished project I've made as of April 18th, 2026. Overall, I'm really happy with how it turned out and with everything that I learned while making it.

## 📈 What I learned
- Gameplay scripting
- Economy balancing
- UI systems
- Data persistence
- Client/server communication
- Debugging and iteration
- Long-term solo project management

### 🔧 What I could have improved
- Clicking Performance — Whenever a player clicked a button to gain cash the client would send a remote to the server and do a bunch of validation and anti cheat checks. During full servers of players this caused a lot of unnecessary server/network load. Players on mobile devices suffered the most from this. A better approach would have been to batch clicks into timed requests and also to add a rate limit on the requests.
- UI Design — Some UI elements could have been improved by using a consistent visual style and stronger theme identites throughout menus.

### 🎥 Game showcase video (1m 35s):
https://www.youtube.com/watch?v=usSjExjc3eE

## 🖼️ Pictures
### Lobby / UI
![picture-button-tappers-lobby.png](picture-button-tappers-lobby.png)
### Area
![picture-button-tappers-area.png](picture-button-tappers-area.png)
### Prestige 3 Aura
![picture-button-tappers-aura.png](picture-button-tappers-aura.png)
