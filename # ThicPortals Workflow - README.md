# ThicPortals Addon - README

## Overview

**ThicPortals** is a World of Warcraft Classic addon designed to streamline mage portal services. It manages customer requests, tracks portal transactions, provides a paginated ticket UI, and keeps detailed statistics on trades and gold earned.

---

## Typical Transaction Flow

### 1. **Customer Request**

-   A player whispers the mage with a portal request.
-   The addon parses the message for keywords/phrases using `Utils.messageHasPhraseOrKeyword`.
-   If a valid request is detected, a new ticket is created in `Events.pendingInvites` for the customer.

### 2. **Ticket Creation & UI**

-   The ticket is added to `Events.pendingInvites` and `UI.ticketList`.
-   The paginated ticket window (`UI.showPaginatedTicketWindow`) is shown or updated.
-   Each ticket displays:
    -   Player name
    -   Destination
    -   Distance (auto-updating)
    -   Original message (toggleable view)
    -   Portal button (casts portal or switches to trade icon if portal is live)
    -   Remove button (removes customer from group)
    -   Navigation buttons (Next/Previous for multiple tickets)

### 3. **Customer Joins Group**

-   When the customer joins, `GROUP_ROSTER_UPDATE` fires.
-   The addon marks the ticket as `hasJoined`, flashes the WoW icon, and sends a whisper with instructions.
-   If enabled, food/water support messages are sent.
-   The UI is updated to reflect the new group member.

### 4. **Portal Casting**

-   When the mage casts a portal, `Config.CurrentAlivePortals` is updated.
-   The portal button icon for the relevant ticket changes to a coin icon (`UI.setTradeIcon`) to indicate the portal is live and trade is expected.
-   The button tooltip updates to prompt the mage to trade with the customer.

### 5. **Customer Travels**

-   The addon tracks the customer's position using `Utils.updateDistanceLabel` and `Utils.isPlayerWithinRange`.
-   When the customer is within range of the portal, the ticket is marked as `travelled`.
-   The UI updates to show a "Complete" tick and disables the portal button.

### 6. **Trade Completion**

-   When a trade is completed, `Utils.addTipToRollingTotal` updates gold statistics.
-   `Utils.incrementTradesCompleted` increments the trade count.
-   Gold earned is displayed in the chat.

### 7. **Customer Leaves Group**

-   If the customer leaves the group (manually or after travelling), `GROUP_ROSTER_UPDATE` detects this.
-   The ticket is removed from `Events.pendingInvites` and `UI.ticketList`.
-   If more tickets remain, the UI paginates to the next ticket; if not, the ticket window closes.

---

## Key Files & Functions

-   **UI.lua**

    -   `UI.showPaginatedTicketWindow`: Main ticket window logic.
    -   `UI.updateTicketFrame`: Updates UI for the current ticket.
    -   `UI.setIconSpell` / `UI.setTradeIcon`: Handles portal/trade button icons.
    -   Navigation and message view toggling.

-   **Events.lua**

    -   Handles WoW events like `GROUP_ROSTER_UPDATE`.
    -   Manages ticket lifecycle: creation, join, leave, and removal.

-   **Utils.lua**
    -   Keyword/message parsing.
    -   Distance calculation and live updating.
    -   Gold/trade statistics.
    -   Portal destination matching.

---

## Statistics & Gold Tracking

-   **Total and daily gold** are tracked and displayed after each trade.
-   **Trade count** is incremented per completed transaction.
-   Daily gold resets automatically each day.

---

## Customization

-   **Keywords** for portal requests can be configured.
-   **Ban list** support for ignoring certain players.
-   **Debug mode** prints detailed logs for troubleshooting.

---

## UI Features

-   **Paginated ticket window**: Manage multiple requests without overlap.
-   **Dynamic distance tracking**: See how far each customer is.
-   **Message view toggle**: Review the original customer request.
-   **Portal/trade icon switching**: Visual cues for each transaction stage.
-   **Navigation buttons**: Easily switch between active tickets.

---

## Typical Addon Flow Diagram

```
Customer whispers → Ticket created → Ticket UI shown
        ↓
Customer joins group → Instructions sent → Portal cast
        ↓
Portal button switches to coin icon (trade)
        ↓
Customer travels → Marked as travelled → Trade completed
        ↓
Gold/trade stats updated → Customer leaves group
        ↓
Ticket removed, UI paginates or closes
```

---

## Troubleshooting

-   **Distance flickering**: The addon ensures only the current ticket's distance is updated.
-   **Portal button not clickable**: The button is always enabled unless the ticket is marked as completed.
-   **Navigation buttons**: Only enabled when multiple tickets exist.

---

## Credits

Addon created by [Thic-Ashbringer EU].
For support or suggestions, whisper in-game or open an issue on GitHub.

---
