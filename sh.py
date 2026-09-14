"""
============================================================
🎴 سرور پیشرفته بازی‌های پاسور ایرانی  (نسخه اصلاح‌شده)
پشتیبانی از: چهاربرگ (یازده) | هفت خبیث | شلم | حکم
============================================================
"""

# ---------- Imports ----------
import os
import json
import uuid
import random
import asyncio
import hashlib
import hmac
import time
import secrets
import logging
from contextlib import asynccontextmanager
from datetime import datetime, timedelta
from enum import Enum
from typing import Dict, List, Optional, Set, Tuple, Any
from collections import defaultdict, deque

from fastapi import (
    FastAPI, WebSocket, WebSocketDisconnect, Depends, HTTPException,
    status, Query, Request, Body
)
from fastapi.security import APIKeyHeader
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import HTMLResponse
from pydantic import BaseModel, Field

# Pydantic v1/v2 compat
try:
    from pydantic import field_validator
    _PYDANTIC_V2 = True
except ImportError:
    from pydantic import validator as field_validator
    _PYDANTIC_V2 = False

def _fv(field_name: str):
    """Decorator shim برای سازگاری Pydantic v1/v2"""
    if _PYDANTIC_V2:
        def deco(fn):
            return field_validator(field_name, mode="before")(classmethod(fn))
        return deco
    else:
        def deco(fn):
            return field_validator(field_name, allow_reuse=True)(fn)
        return deco

import uvicorn

# ---------- Logging ----------
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s | %(levelname)-7s | %(message)s",
    datefmt="%H:%M:%S"
)
log = logging.getLogger("paskar")

# ============================================================
# CONFIG
# ============================================================
API_KEY = os.getenv("RDP_PASSWORD", "default-secret-change-me")
DB_PATH = os.getenv("DB_PATH", "paskar_db.json")
TURN_TIMEOUT = int(os.getenv("TURN_TIMEOUT", "30"))
SESSION_TTL = timedelta(days=7)
MAX_ROOMS_PER_USER = 20
MAX_CHAT_HISTORY = 200
RATE_LIMIT_WINDOW = 1.0
RATE_LIMIT_MAX = 20

# ============================================================
# PERSISTENCE
# ============================================================
class PersistentStore:
    def __init__(self, path: str):
        self.path = path
        self.lock = asyncio.Lock()
        self._dirty = False
        self._save_task = None

    async def load(self) -> dict:
        if not os.path.exists(self.path):
            return self._default()
        try:
            with open(self.path, "r", encoding="utf-8") as f:
                data = json.load(f)
            base = self._default()
            for k in base:
                base[k] = data.get(k, base[k])
            return base
        except Exception as e:
            log.error(f"DB load failed: {e}")
            return self._default()

    def _default(self) -> dict:
        return {
            "users": {}, "sessions": {},
            "friends": {}, "friend_requests": {},
            "rooms": {}, "chat_history": {}, "game_history": {},
            "notifications": {}, "achievements": {}, "blocked": {},
        }

    def mark_dirty(self):
        self._dirty = True

    async def _save_loop(self):
        while True:
            await asyncio.sleep(5)
            if self._dirty:
                await self.save()

    def _json_safe(self, obj):
        if isinstance(obj, dict):
            return {k: self._json_safe(v) for k, v in obj.items()}
        if isinstance(obj, (set, frozenset)):
            return sorted(list(obj), key=str)
        if isinstance(obj, (list, tuple)):
            return [self._json_safe(x) for x in obj]
        if hasattr(obj, "__dict__") and not isinstance(obj, (str, int, float, bool, type(None))):
            return None
        return obj

    async def save(self):
        async with self.lock:
            try:
                safe_rooms = {}
                for rid, r in DB["rooms"].items():
                    rr = {k: v for k, v in r.items() if k != "game_instance"}
                    safe_rooms[rid] = self._json_safe(rr)

                snapshot = {
                    "users": self._json_safe(DB["users"]),
                    "sessions": self._json_safe(DB["sessions"]),
                    "friends": {k: sorted(list(v), key=str) for k, v in DB["friends"].items()},
                    "friend_requests": {k: sorted(list(v), key=str) for k, v in DB["friend_requests"].items()},
                    "rooms": safe_rooms,
                    "chat_history": {k: v[-MAX_CHAT_HISTORY:] for k, v in DB["chat_history"].items()},
                    "game_history": self._json_safe(DB["game_history"]),
                    "notifications": {k: v[-100:] for k, v in DB["notifications"].items()},
                    "achievements": {k: sorted(list(v), key=str) for k, v in DB["achievements"].items()},
                    "blocked": {k: sorted(list(v), key=str) for k, v in DB["blocked"].items()},
                }
                tmp = self.path + ".tmp"
                with open(tmp, "w", encoding="utf-8") as f:
                    json.dump(snapshot, f, ensure_ascii=False, default=str)
                os.replace(tmp, self.path)
                self._dirty = False
            except Exception as e:
                log.error(f"DB save failed: {e}")

    async def start(self):
        self._save_task = asyncio.create_task(self._save_loop())

    async def stop(self):
        if self._save_task:
            self._save_task.cancel()
            try:
                await self._save_task
            except asyncio.CancelledError:
                pass
        await self.save()


STORE = PersistentStore(DB_PATH)

# Global DB
DB: dict = STORE._default()

def _hydrate_sets():
    for k in ("friends", "friend_requests", "achievements", "blocked"):
        for user, lst in list(DB.get(k, {}).items()):
            DB[k][user] = set(lst or [])
    for rid, r in list(DB.get("rooms", {}).items()):
        if isinstance(r.get("ready"), list):
            r["ready"] = set(r["ready"])
        elif not isinstance(r.get("ready"), set):
            r["ready"] = set()
        r["game_instance"] = None
        r.setdefault("status", "waiting")
        r.setdefault("players", [])
        r.setdefault("spectators", [])

# ============================================================
# MODELS
# ============================================================
class GameType(str, Enum):
    CHAHAR_BARG = "chahar_barg"
    HAFT_KHABIS = "haft_khabis"
    SHELEM = "shelem"
    HOKM = "hokm"

class Suit(str, Enum):
    HEARTS = "hearts"
    DIAMONDS = "diamonds"
    CLUBS = "clubs"
    SPADES = "spades"

SUIT_FA = {
    "hearts": "♥ دل", "diamonds": "♦ خشت",
    "clubs": "♣ گشنیز", "spades": "♠ پیک"
}

class Rank(str, Enum):
    TWO = "2"; THREE = "3"; FOUR = "4"; FIVE = "5"; SIX = "6"; SEVEN = "7"
    EIGHT = "8"; NINE = "9"; TEN = "10"; JACK = "J"; QUEEN = "Q"; KING = "K"; ACE = "A"

class RegisterReq(BaseModel):
    username: str = Field(..., min_length=2, max_length=32)
    password: Optional[str] = Field(None, max_length=128)
    avatar: Optional[str] = None
    bio: Optional[str] = Field(None, max_length=200)

    @_fv("username")
    @classmethod
    def _check_username(cls, v):
        v = (v or "").strip()
        if not all(c.isalnum() or c in "_-." for c in v):
            raise ValueError("نام کاربری فقط حروف/عدد/._- مجاز است")
        return v

class LoginReq(BaseModel):
    username: str
    password: Optional[str] = None

class RoomCreateReq(BaseModel):
    name: str = Field(..., min_length=1, max_length=60)
    game_type: GameType
    max_players: int = Field(4, ge=2, le=8)
    password: Optional[str] = Field(None, max_length=32)
    is_private: bool = False
    allow_spectators: bool = True
    chat_enabled: bool = True
    voice_enabled: bool = True
    turn_timeout: int = Field(TURN_TIMEOUT, ge=10, le=120)
    target_score: Optional[int] = None

class FriendReq(BaseModel):
    username: str

# ============================================================
# CARDS
# ============================================================
class Card:
    __slots__ = ("suit", "rank")
    def __init__(self, suit: Suit, rank: Rank):
        self.suit, self.rank = suit, rank
    def to_dict(self):
        return {"suit": self.suit.value, "rank": self.rank.value,
                "label": f"{self.rank.value}{'♥♦♣♠'[list(Suit).index(self.suit)]}"}
    def __repr__(self):
        return f"{self.rank.value}{self.suit.value[0].upper()}"
    def __eq__(self, o):
        return isinstance(o, Card) and self.suit == o.suit and self.rank == o.rank
    def __hash__(self):
        return hash((self.suit, self.rank))

RANK_ORDER = {
    Rank.TWO: 2, Rank.THREE: 3, Rank.FOUR: 4, Rank.FIVE: 5, Rank.SIX: 6,
    Rank.SEVEN: 7, Rank.EIGHT: 8, Rank.NINE: 9, Rank.TEN: 10, Rank.JACK: 11,
    Rank.QUEEN: 12, Rank.KING: 13, Rank.ACE: 14
}
RANK_NUM = {
    Rank.ACE: 1, Rank.TWO: 2, Rank.THREE: 3, Rank.FOUR: 4, Rank.FIVE: 5,
    Rank.SIX: 6, Rank.SEVEN: 7, Rank.EIGHT: 8, Rank.NINE: 9, Rank.TEN: 10,
    Rank.JACK: 11, Rank.QUEEN: 12, Rank.KING: 13
}

class Deck:
    def __init__(self):
        self.reset()
    def reset(self):
        self.cards = [Card(s, r) for s in Suit for r in Rank]
    def shuffle(self, seed: Optional[int] = None):
        rnd = random.Random(seed) if seed is not None else random
        rnd.shuffle(self.cards)
    def deal(self, n: int) -> List[Card]:
        out = self.cards[:n]; self.cards = self.cards[n:]; return out

# ============================================================
# GAME ENGINE
# ============================================================
class BaseGame:
    game_type: str = "base"
    def __init__(self, players: List[str], options: Optional[dict] = None):
        self.players = players
        self.options = options or {}
        self.started_at = time.time()
        self.moves: List[dict] = []
        self.finished = False
        self.winner: Optional[str] = None
        self.winners: List[str] = []
        self.current_turn: int = 0
        self.turn_deadline: Optional[float] = None

    def _log(self, **kw):
        kw["t"] = time.time()
        self.moves.append(kw)

    def set_turn(self, idx: int, timeout: int = TURN_TIMEOUT):
        self.current_turn = idx
        self.turn_deadline = time.time() + timeout

    def time_left(self) -> float:
        if not self.turn_deadline: return 0.0
        return max(0.0, self.turn_deadline - time.time())

    def is_turn_expired(self) -> bool:
        return self.turn_deadline is not None and time.time() > self.turn_deadline

    def public_state(self) -> dict:
        raise NotImplementedError

    def personal_state(self, user: str) -> dict:
        return self.public_state()

    def play_card(self, user: str, idx: int) -> dict:
        raise NotImplementedError

    def auto_play(self, user: str) -> Optional[dict]:
        return None


# ---------- چهاربرگ ----------
class ChaharBargGame(BaseGame):
    game_type = "chahar_barg"
    def __init__(self, players, options=None):
        super().__init__(players, options)
        self.deck = Deck(); self.deck.shuffle()
        self.hands: Dict[str, List[Card]] = {}
        self.table: List[Card] = []
        self.captured: Dict[str, List[Card]] = {p: [] for p in players}
        self.scores: Dict[str, int] = {p: 0 for p in players}
        self.last_capturer: Optional[str] = None

    def start(self):
        for p in self.players:
            self.hands[p] = self.deck.deal(4)
        non_jacks = [c for c in self.deck.cards if c.rank != Rank.JACK]
        random.shuffle(non_jacks)
        table = []
        for _ in range(4):
            if non_jacks:
                c = non_jacks.pop()
                if c in self.deck.cards:
                    self.deck.cards.remove(c)
                table.append(c)
        self.table = table
        self.set_turn(0, self.options.get("turn_timeout", TURN_TIMEOUT))
        self._log(event="start", players=self.players)

    def _capture_with_card(self, card: Card) -> List[Card]:
        cap: List[Card] = []
        if card.rank == Rank.JACK:
            remaining = []
            for tc in self.table:
                if tc.rank in (Rank.KING, Rank.QUEEN):
                    remaining.append(tc)
                else:
                    cap.append(tc)
            self.table = remaining
        elif card.rank == Rank.KING:
            for i, tc in enumerate(self.table):
                if tc.rank == Rank.KING:
                    cap.append(self.table.pop(i)); break
        elif card.rank == Rank.QUEEN:
            for i, tc in enumerate(self.table):
                if tc.rank == Rank.QUEEN:
                    cap.append(self.table.pop(i)); break
        elif card.rank == Rank.SEVEN:
            i4 = next((i for i, t in enumerate(self.table) if RANK_NUM[t.rank] == 4), None)
            i3 = next((i for i, t in enumerate(self.table) if RANK_NUM[t.rank] == 3 and i != i4), None)
            if i4 is not None and i3 is not None:
                idxs = sorted([i4, i3], reverse=True)
                for i in idxs:
                    cap.append(self.table.pop(i))
        else:
            target = 11 - RANK_NUM[card.rank]
            best_pair = None
            for i in range(len(self.table)):
                for j in range(i + 1, len(self.table)):
                    a, b = self.table[i], self.table[j]
                    if a.rank in (Rank.KING, Rank.QUEEN, Rank.JACK): continue
                    if b.rank in (Rank.KING, Rank.QUEEN, Rank.JACK): continue
                    if RANK_NUM[a.rank] + RANK_NUM[b.rank] == target:
                        best_pair = (i, j); break
                if best_pair: break
            if best_pair:
                i, j = sorted(best_pair, reverse=True)
                cap.append(self.table.pop(i)); cap.append(self.table.pop(j))
            else:
                for i, tc in enumerate(self.table):
                    if tc.rank in (Rank.KING, Rank.QUEEN, Rank.JACK): continue
                    if RANK_NUM[tc.rank] == target:
                        cap.append(self.table.pop(i)); break
        return cap

    def play_card(self, user: str, idx: int) -> dict:
        if self.finished: return {"error": "بازی تمام شده"}
        if user != self.players[self.current_turn]:
            return {"error": "نوبت شما نیست"}
        hand = self.hands.get(user, [])
        if not (0 <= idx < len(hand)): return {"error": "ایندکس نامعتبر"}
        card = hand.pop(idx)
        cap = self._capture_with_card(card)
        if cap:
            self.captured[user].extend(cap); self.captured[user].append(card)
            self.scores[user] += len(cap) + 1
            self.last_capturer = user
        else:
            self.table.append(card)
        if all(len(h) == 0 for h in self.hands.values()) and not self.deck.cards:
            if self.last_capturer and self.table:
                self.captured[self.last_capturer].extend(self.table)
                self.scores[self.last_capturer] += len(self.table)
                self.table = []
            self.finished = True
            if self.scores:
                best = max(self.scores.values())
                self.winners = [p for p, s in self.scores.items() if s == best]
                self.winner = self.winners[0] if len(self.winners) == 1 else None
        self._log(user=user, card=card.to_dict(), captured=[c.to_dict() for c in cap])
        if not self.finished:
            self.set_turn((self.current_turn + 1) % len(self.players),
                          self.options.get("turn_timeout", TURN_TIMEOUT))
        return {"ok": True}

    def auto_play(self, user: str) -> Optional[dict]:
        if user != self.players[self.current_turn]: return None
        hand = self.hands[user]
        if not hand: return None
        best_i, best_n = 0, -1
        for i, c in enumerate(hand):
            saved = list(self.table)
            cap = self._capture_with_card(c)
            n = len(cap)
            self.table = saved
            if n > best_n:
                best_n, best_i = n, i
        return self.play_card(user, best_i)

    def public_state(self):
        return {
            "game_type": self.game_type,
            "players": self.players,
            "scores": self.scores,
            "table": [c.to_dict() for c in self.table],
            "hand_counts": {p: len(self.hands.get(p, [])) for p in self.players},
            "current_turn": self.players[self.current_turn] if not self.finished else None,
            "time_left": self.time_left(),
            "finished": self.finished,
            "winners": self.winners,
            "last_capturer": self.last_capturer,
        }

    def personal_state(self, user: str):
        s = self.public_state()
        s["hand"] = [c.to_dict() for c in self.hands.get(user, [])]
        return s


# ---------- هفت خبیث ----------
class HaftKhabisGame(BaseGame):
    game_type = "haft_khabis"
    def __init__(self, players, options=None):
        super().__init__(players, options)
        self.deck = Deck(); self.deck.shuffle()
        self.hands: Dict[str, List[Card]] = {}
        self.discard: List[Card] = []
        self.direction = 1
        self.pending_draw = 0
        self.pending_type: Optional[str] = None
        self.declared_suit: Optional[Suit] = None

    def start(self):
        for p in self.players:
            self.hands[p] = self.deck.deal(7)
        special = {Rank.ACE, Rank.TWO, Rank.SEVEN, Rank.EIGHT, Rank.TEN, Rank.JACK}
        candidates = [c for c in self.deck.cards if c.rank not in special]
        if candidates:
            c = random.choice(candidates)
            self.deck.cards.remove(c)
            self.discard.append(c)
        self.set_turn(0, self.options.get("turn_timeout", TURN_TIMEOUT))
        self._log(event="start")

    def _advance(self, skip: int = 0):
        total = len(self.players)
        self.current_turn = (self.current_turn + (1 + skip) * self.direction) % total

    def _valid(self, card: Card) -> bool:
        top = self.discard[-1] if self.discard else None
        if not top: return True
        if self.pending_draw > 0 and self.pending_type == "7":
            return card.rank == Rank.SEVEN
        if card.rank == Rank.TEN or card.rank == Rank.ACE: return True
        if self.declared_suit:
            return card.suit == self.declared_suit
        return card.suit == top.suit or card.rank == top.rank

    def play_card(self, user: str, idx: int, declared_suit: Optional[str] = None) -> dict:
        if self.finished: return {"error": "بازی تمام شده"}
        if user != self.players[self.current_turn]:
            return {"error": "نوبت شما نیست"}
        hand = self.hands.get(user, [])
        if not (0 <= idx < len(hand)): return {"error": "ایندکس نامعتبر"}
        card = hand[idx]

        if self.pending_draw > 0 and self.pending_type == "2":
            if card.rank != Rank.TWO:
                drawn = self.deck.deal(min(self.pending_draw, len(self.deck.cards)))
                self.hands[user].extend(drawn)
                self.pending_draw = 0; self.pending_type = None
                self._log(user=user, action="penalty_draw", drawn=[c.to_dict() for c in drawn])
                self._advance(0)
                self.set_turn(self.current_turn, self.options.get("turn_timeout", TURN_TIMEOUT))
                return {"ok": True, "drew": [c.to_dict() for c in drawn]}

        if self.pending_draw > 0 and self.pending_type == "7":
            if card.rank != Rank.SEVEN:
                drawn = self.deck.deal(min(self.pending_draw, len(self.deck.cards)))
                self.hands[user].extend(drawn)
                self.pending_draw = 0; self.pending_type = None
                self._log(user=user, action="penalty_draw7", drawn=[c.to_dict() for c in drawn])
                self._advance(0)
                self.set_turn(self.current_turn, self.options.get("turn_timeout", TURN_TIMEOUT))
                return {"ok": True, "drew": [c.to_dict() for c in drawn]}

        if not self._valid(card):
            return {"error": "این کارت مجاز نیست"}

        hand.pop(idx)
        self.discard.append(card)
        self.declared_suit = None
        skip = 0

        if card.rank == Rank.SEVEN:
            self.pending_draw += 2; self.pending_type = "7"
        elif card.rank == Rank.TWO:
            self.pending_draw += 2; self.pending_type = "2"
        elif card.rank == Rank.EIGHT:
            skip = 1
        elif card.rank == Rank.ACE:
            skip = 1
            self.direction *= -1
        elif card.rank == Rank.TEN:
            if declared_suit:
                try: self.declared_suit = Suit(declared_suit)
                except Exception: pass

        if not hand:
            self.finished = True
            self.winner = user; self.winners = [user]
            self._log(user=user, action="win")

        if not self.finished:
            self._advance(skip)
            self.set_turn(self.current_turn, self.options.get("turn_timeout", TURN_TIMEOUT))

        self._log(user=user, card=card.to_dict(),
                  declared_suit=self.declared_suit.value if self.declared_suit else None)
        return {"ok": True}

    def auto_play(self, user: str) -> Optional[dict]:
        if user != self.players[self.current_turn]: return None
        hand = self.hands[user]
        if not hand: return None
        valid = [i for i, c in enumerate(hand) if self._valid(c)]
        if not valid:
            if self.deck.cards:
                c = self.deck.deal(1)[0]
                self.hands[user].append(c)
                self._advance(0)
                self.set_turn(self.current_turn, self.options.get("turn_timeout", TURN_TIMEOUT))
                return {"drew": c.to_dict()}
            return None
        priority = {Rank.SEVEN: 10, Rank.TWO: 9, Rank.EIGHT: 8, Rank.ACE: 7, Rank.TEN: 5}
        best = max(valid, key=lambda i: priority.get(hand[i].rank, 0))
        card = hand[best]
        decl = None
        if card.rank == Rank.TEN:
            suits = [c.suit.value for c in hand if c.rank != Rank.TEN]
            if suits: decl = max(set(suits), key=suits.count)
        return self.play_card(user, best, decl)

    def public_state(self):
        return {
            "game_type": self.game_type,
            "players": self.players,
            "discard_top": self.discard[-1].to_dict() if self.discard else None,
            "discard_count": len(self.discard),
            "hand_counts": {p: len(self.hands.get(p, [])) for p in self.players},
            "current_turn": self.players[self.current_turn] if not self.finished else None,
            "direction": self.direction,
            "pending_draw": self.pending_draw,
            "pending_type": self.pending_type,
            "declared_suit": self.declared_suit.value if self.declared_suit else None,
            "time_left": self.time_left(),
            "finished": self.finished,
            "winner": self.winner,
        }

    def personal_state(self, user: str):
        s = self.public_state()
        s["hand"] = [c.to_dict() for c in self.hands.get(user, [])]
        return s


# ---------- شلم ----------
class ShelemGame(BaseGame):
    """
    شلم با امتیازدهی: A=10، 10=10، 5=5
    مجموع هر دست = 100 امتیاز
    """
    game_type = "shelem"
    CARD_POINTS = {Rank.ACE: 10, Rank.TEN: 10, Rank.FIVE: 5}

    def __init__(self, players, options=None):
        super().__init__(players, options)
        if len(players) != 4:
            raise ValueError("شلم به ۴ بازیکن نیاز دارد")
        self.deck = Deck(); self.deck.shuffle()
        self.hands: Dict[str, List[Card]] = {}
        self.teams = {"team1": [players[0], players[2]], "team2": [players[1], players[3]]}
        self.scores = {"team1": 0, "team2": 0}
        self.target_score = (options or {}).get("target_score", 1000)
        self.hakem: Optional[str] = None
        self.hokm_suit: Optional[Suit] = None
        self.bids: Dict[str, Optional[int]] = {}
        self.current_bid_winner: Optional[str] = None
        self.current_bid: int = 0
        self.phase: str = "bidding"
        self.trick: List[Tuple[str, Card]] = []
        self.tricks_won = {"team1": 0, "team2": 0}
        self.round_scores = {"team1": 0, "team2": 0}
        self.bid_team: Optional[str] = None
        self.bid_amount: int = 0

    def start(self):
        for p in self.players:
            self.hands[p] = self.deck.deal(13)
        self.bids = {p: None for p in self.players}
        self.set_turn(0, self.options.get("turn_timeout", TURN_TIMEOUT))
        self._log(event="start", phase="bidding")

    def place_bid(self, user: str, amount: Optional[int]) -> dict:
        if self.phase != "bidding": return {"error": "فاز مزایده نیست"}
        if user != self.players[self.current_turn]:
            return {"error": "نوبت شما نیست"}
        if amount is not None:
            if amount < 100 or amount > 165:
                return {"error": "مقدار پیشنهاد باید بین ۱۰۰ و ۱۶۵ باشد"}
            if amount <= self.current_bid:
                return {"error": "پیشنهاد شما باید بیشتر از پیشنهاد فعلی باشد"}
            self.current_bid = amount
            self.current_bid_winner = user
        self.bids[user] = amount

        remaining = [p for p in self.players if self.bids[p] is None]
        if not remaining:
            if not self.current_bid_winner:
                self.current_bid_winner = self.players[0]
                self.current_bid = 100
            self.hakem = self.current_bid_winner
            self.bid_amount = self.current_bid
            self.bid_team = "team1" if self.hakem in self.teams["team1"] else "team2"
            self.phase = "select_hokm"
            return {"ok": True, "phase": "select_hokm", "hakem": self.hakem}

        idx = self.players.index(user)
        self.set_turn((idx + 1) % 4, self.options.get("turn_timeout", TURN_TIMEOUT))
        self._log(user=user, bid=amount)
        return {"ok": True, "next": self.players[self.current_turn]}

    def select_hokm(self, user: str, suit: str) -> dict:
        if self.phase != "select_hokm": return {"error": "فاز انتخاب حکم نیست"}
        if user != self.hakem: return {"error": "فقط حاکم می‌تواند حکم را انتخاب کند"}
        try: self.hokm_suit = Suit(suit)
        except Exception: return {"error": "خال نامعتبر"}
        self.phase = "playing"
        self.set_turn(self.players.index(self.hakem),
                      self.options.get("turn_timeout", TURN_TIMEOUT))
        self._log(user=user, action="hokm_selected", suit=suit)
        return {"ok": True}

    def _card_points(self, c: Card) -> int:
        return self.CARD_POINTS.get(c.rank, 0)

    def _trick_winner(self) -> str:
        lead = self.trick[0][1].suit
        best_p, best_c = self.trick[0]
        for p, c in self.trick[1:]:
            if c.suit == self.hokm_suit and best_c.suit != self.hokm_suit:
                best_p, best_c = p, c
            elif c.suit == best_c.suit:
                if RANK_ORDER[c.rank] > RANK_ORDER[best_c.rank]:
                    best_p, best_c = p, c
            elif best_c.suit != self.hokm_suit and c.suit == lead:
                if best_c.suit != lead or RANK_ORDER[c.rank] > RANK_ORDER[best_c.rank]:
                    best_p, best_c = p, c
        return best_p

    def _valid_play(self, user: str, card: Card) -> Optional[str]:
        if not self.trick: return None
        lead = self.trick[0][1].suit
        hand = self.hands[user]
        has_lead = any(c.suit == lead for c in hand)
        if has_lead and card.suit != lead:
            return f"باید از خال {SUIT_FA[lead.value]} بازی کنید"
        return None

    def play_card(self, user: str, idx: int) -> dict:
        if self.phase != "playing": return {"error": "فاز بازی نیست"}
        if self.finished: return {"error": "بازی تمام شده"}
        if user != self.players[self.current_turn]:
            return {"error": "نوبت شما نیست"}
        hand = self.hands.get(user, [])
        if not (0 <= idx < len(hand)): return {"error": "ایندکس نامعتبر"}
        card = hand[idx]
        err = self._valid_play(user, card)
        if err: return {"error": err}
        hand.pop(idx)
        self.trick.append((user, card))

        if len(self.trick) == 4:
            winner = self._trick_winner()
            wteam = "team1" if winner in self.teams["team1"] else "team2"
            self.tricks_won[wteam] += 1
            pts = sum(self._card_points(c) for _, c in self.trick)
            self.round_scores[wteam] += pts
            self.trick = []
            self._log(action="trick", winner=winner, pts=pts)
            if not any(self.hands[p] for p in self.players):
                self._end_round()
            else:
                self.set_turn(self.players.index(winner),
                              self.options.get("turn_timeout", TURN_TIMEOUT))
            return {"ok": True}
        else:
            idx2 = self.players.index(user)
            self.set_turn((idx2 + 1) % 4, self.options.get("turn_timeout", TURN_TIMEOUT))
            self._log(user=user, card=card.to_dict())
            return {"ok": True}

    def _end_round(self):
        bid_team = self.bid_team
        opp_team = "team2" if bid_team == "team1" else "team1"
        self.scores[bid_team] += self.round_scores[bid_team]
        self.scores[opp_team] += self.round_scores[opp_team]
        if self.round_scores[bid_team] < self.bid_amount:
            self.scores[bid_team] -= 2 * self.bid_amount
            self._log(action="bid_failed")
        if self.scores["team1"] >= self.target_score or self.scores["team2"] >= self.target_score:
            self.finished = True
            if self.scores["team1"] >= self.target_score:
                self.winners = self.teams["team1"]
            if self.scores["team2"] >= self.target_score:
                self.winners = self.teams["team2"]
            self.winner = self.winners[0] if self.winners else None
        self._log(action="round_end",
                  round_scores=self.round_scores,
                  total_scores=self.scores,
                  bid=self.bid_amount,
                  bid_team=bid_team)

    def auto_play(self, user: str) -> Optional[dict]:
        if self.phase == "bidding":
            if user != self.players[self.current_turn]: return None
            return self.place_bid(user, None)
        if self.phase == "select_hokm":
            if user != self.hakem: return None
            return self.select_hokm(user, random.choice(list(Suit)).value)
        if self.phase != "playing": return None
        if user != self.players[self.current_turn]: return None
        hand = self.hands[user]
        if not hand: return None
        valid = [i for i, c in enumerate(hand) if self._valid_play(user, c) is None]
        if not valid: valid = list(range(len(hand)))
        best = min(valid, key=lambda i: self._card_points(hand[i]))
        return self.play_card(user, best)

    def public_state(self):
        return {
            "game_type": self.game_type,
            "players": self.players,
            "teams": self.teams,
            "phase": self.phase,
            "bids": self.bids,
            "current_bid": self.current_bid,
            "current_bid_winner": self.current_bid_winner,
            "hakem": self.hakem,
            "hokm_suit": self.hokm_suit.value if self.hokm_suit else None,
            "scores": self.scores,
            "round_scores": self.round_scores,
            "tricks_won": self.tricks_won,
            "trick": [(p, c.to_dict()) for p, c in self.trick],
            "hand_counts": {p: len(self.hands.get(p, [])) for p in self.players},
            "current_turn": self.players[self.current_turn] if not self.finished else None,
            "time_left": self.time_left(),
            "finished": self.finished,
            "winners": self.winners,
            "target_score": self.target_score,
        }

    def personal_state(self, user: str):
        s = self.public_state()
        s["hand"] = [c.to_dict() for c in self.hands.get(user, [])]
        return s


# ---------- حکم ----------
class HokmGame(BaseGame):
    game_type = "hokm"
    def __init__(self, players, options=None):
        super().__init__(players, options)
        if len(players) != 4:
            raise ValueError("حکم به ۴ بازیکن نیاز دارد")
        self.deck = Deck(); self.deck.shuffle()
        self.hands: Dict[str, List[Card]] = {}
        self.teams = {"team1": [players[0], players[2]], "team2": [players[1], players[3]]}
        self.hakem = players[0]
        self.hokm_suit: Optional[Suit] = None
        self.tricks_won = {"team1": 0, "team2": 0}
        self.trick: List[Tuple[str, Card]] = []
        self.phase = "select_hokm"
        self.scores = {"team1": 0, "team2": 0}

    def start(self):
        for p in self.players:
            self.hands[p] = self.deck.deal(13)
        self.phase = "select_hokm"
        self.set_turn(self.players.index(self.hakem),
                      self.options.get("turn_timeout", TURN_TIMEOUT))
        self._log(event="start", hakem=self.hakem)

    def select_hokm(self, user: str, suit: str) -> dict:
        if self.phase != "select_hokm": return {"error": "فاز انتخاب حکم نیست"}
        if user != self.hakem: return {"error": "فقط حاکم می‌تواند حکم را انتخاب کند"}
        try: self.hokm_suit = Suit(suit)
        except Exception: return {"error": "خال نامعتبر"}
        self.phase = "playing"
        self.set_turn(self.players.index(self.hakem),
                      self.options.get("turn_timeout", TURN_TIMEOUT))
        self._log(user=user, action="hokm_selected", suit=suit)
        return {"ok": True}

    def _trick_winner(self) -> str:
        lead = self.trick[0][1].suit
        best_p, best_c = self.trick[0]
        for p, c in self.trick[1:]:
            if c.suit == self.hokm_suit and best_c.suit != self.hokm_suit:
                best_p, best_c = p, c
            elif c.suit == best_c.suit:
                if RANK_ORDER[c.rank] > RANK_ORDER[best_c.rank]:
                    best_p, best_c = p, c
            elif best_c.suit != self.hokm_suit and c.suit == lead:
                if best_c.suit != lead or RANK_ORDER[c.rank] > RANK_ORDER[best_c.rank]:
                    best_p, best_c = p, c
        return best_p

    def _valid_play(self, user: str, card: Card) -> Optional[str]:
        if not self.trick: return None
        lead = self.trick[0][1].suit
        has_lead = any(c.suit == lead for c in self.hands[user])
        if has_lead and card.suit != lead:
            return f"باید از خال {SUIT_FA[lead.value]} بازی کنید"
        return None

    def play_card(self, user: str, idx: int) -> dict:
        if self.phase != "playing": return {"error": "فاز بازی نیست"}
        if self.finished: return {"error": "بازی تمام شده"}
        if user != self.players[self.current_turn]:
            return {"error": "نوبت شما نیست"}
        hand = self.hands.get(user, [])
        if not (0 <= idx < len(hand)): return {"error": "ایندکس نامعتبر"}
        card = hand[idx]
        err = self._valid_play(user, card)
        if err: return {"error": err}
        hand.pop(idx)
        self.trick.append((user, card))

        if len(self.trick) == 4:
            winner = self._trick_winner()
            wteam = "team1" if winner in self.teams["team1"] else "team2"
            self.tricks_won[wteam] += 1
            self.trick = []
            if self.tricks_won["team1"] >= 7 or self.tricks_won["team2"] >= 7:
                self.finished = True
                self.winners = self.teams["team1"] if self.tricks_won["team1"] >= 7 else self.teams["team2"]
                self.winner = self.winners[0]
                self.scores["team1"] += 1 if self.tricks_won["team1"] >= 7 else 0
                self.scores["team2"] += 1 if self.tricks_won["team2"] >= 7 else 0
            else:
                self.set_turn(self.players.index(winner),
                              self.options.get("turn_timeout", TURN_TIMEOUT))
            self._log(action="trick", winner=winner)
            return {"ok": True}
        else:
            idx2 = self.players.index(user)
            self.set_turn((idx2 + 1) % 4, self.options.get("turn_timeout", TURN_TIMEOUT))
            self._log(user=user, card=card.to_dict())
            return {"ok": True}

    def auto_play(self, user: str) -> Optional[dict]:
        if self.phase == "select_hokm":
            if user != self.hakem: return None
            return self.select_hokm(user, random.choice(list(Suit)).value)
        if user != self.players[self.current_turn]: return None
        hand = self.hands[user]
        if not hand: return None
        valid = [i for i, c in enumerate(hand) if self._valid_play(user, c) is None]
        if not valid: valid = list(range(len(hand)))
        best = min(valid, key=lambda i: RANK_ORDER[hand[i].rank])
        return self.play_card(user, best)

    def public_state(self):
        return {
            "game_type": self.game_type,
            "players": self.players,
            "teams": self.teams,
            "phase": self.phase,
            "hakem": self.hakem,
            "hokm_suit": self.hokm_suit.value if self.hokm_suit else None,
            "tricks_won": self.tricks_won,
            "scores": self.scores,
            "trick": [(p, c.to_dict()) for p, c in self.trick],
            "hand_counts": {p: len(self.hands.get(p, [])) for p in self.players},
            "current_turn": self.players[self.current_turn] if not self.finished else None,
            "time_left": self.time_left(),
            "finished": self.finished,
            "winners": self.winners,
        }

    def personal_state(self, user: str):
        s = self.public_state()
        s["hand"] = [c.to_dict() for c in self.hands.get(user, [])]
        return s


GAME_CLASSES = {
    "chahar_barg": ChaharBargGame,
    "haft_khabis": HaftKhabisGame,
    "shelem": ShelemGame,
    "hokm": HokmGame,
}

# ============================================================
# CONNECTION MANAGER
# ============================================================
class ConnectionManager:
    def __init__(self):
        self.connections: Dict[str, Dict[str, WebSocket]] = {}
        self.user_sockets: Dict[str, WebSocket] = {}
        self.spectators: Dict[str, Set[str]] = defaultdict(set)
        self.msg_times: Dict[str, deque] = defaultdict(lambda: deque(maxlen=RATE_LIMIT_MAX))
        self.online: Set[str] = set()
        self.turn_tasks: Dict[str, asyncio.Task] = {}
        self.typing: Dict[str, Set[str]] = defaultdict(set)

    async def connect_user(self, username: str, ws: WebSocket):
        self.user_sockets[username] = ws
        self.online.add(username)

    def disconnect_user(self, username: str):
        self.user_sockets.pop(username, None)
        self.online.discard(username)

    async def connect_room(self, room_id: str, username: str, ws: WebSocket, spectator: bool = False):
        self.connections.setdefault(room_id, {})[username] = ws
        if spectator:
            self.spectators[room_id].add(username)

    def disconnect_room(self, room_id: str, username: str):
        if room_id in self.connections:
            self.connections[room_id].pop(username, None)
            if not self.connections[room_id]:
                del self.connections[room_id]
        self.spectators[room_id].discard(username)
        self.typing[room_id].discard(username)

    async def broadcast_room(self, room_id: str, message: dict, exclude: Optional[str] = None):
        for user, ws in list(self.connections.get(room_id, {}).items()):
            if user == exclude: continue
            try: await ws.send_json(message)
            except Exception: pass

    async def send_room(self, room_id: str, username: str, message: dict):
        ws = self.connections.get(room_id, {}).get(username)
        if ws:
            try: await ws.send_json(message)
            except Exception: pass

    async def notify_user(self, username: str, message: dict):
        ws = self.user_sockets.get(username)
        if ws:
            try: await ws.send_json(message)
            except Exception: pass

    def is_rate_limited(self, username: str) -> bool:
        now = time.time()
        dq = self.msg_times[username]
        while dq and now - dq[0] > RATE_LIMIT_WINDOW:
            dq.popleft()
        if len(dq) >= RATE_LIMIT_MAX:
            return True
        dq.append(now)
        return False

MANAGER = ConnectionManager()

# ============================================================
# ACHIEVEMENTS
# ============================================================
ACHIEVEMENTS = {
    "first_win": {"title": "🏆 اولین پیروزی", "desc": "اولین بازی خودت را ببر"},
    "chahar_master": {"title": "🎯 استاد چهاربرگ", "desc": "۱۰ بازی چهاربرگ ببر"},
    "hokm_king": {"title": "👑 پادشاه حکم", "desc": "۱۰ بازی حکم ببر"},
    "shelem_pro": {"title": "💎 حرفه‌ای شلم", "desc": "۱۰ بازی شلم ببر"},
    "haft_champ": {"title": "🎴 قهرمان هفت خبیث", "desc": "۱۰ بازی هفت خبیث ببر"},
    "social": {"title": "🤝 اجتماعی", "desc": "۵ دوست اضافه کن"},
    "chatty": {"title": "💬 پرحرف", "desc": "۱۰۰ پیام چت بفرست"},
    "veteran": {"title": "🎖️ کهنه‌کار", "desc": "۵۰ بازی انجام بده"},
}

def grant_achievement(username: str, key: str):
    if key not in ACHIEVEMENTS: return False
    s = DB["achievements"].setdefault(username, set())
    if key in s: return False
    s.add(key); STORE.mark_dirty()
    try:
        asyncio.create_task(MANAGER.notify_user(username, {
            "type": "achievement", "key": key, "info": ACHIEVEMENTS[key]
        }))
    except RuntimeError:
        pass
    return True

# ============================================================
# HELPERS
# ============================================================
def now_iso(): return datetime.utcnow().isoformat()

def hash_password(pw: str, salt: Optional[str] = None):
    if salt is None:
        salt = secrets.token_hex(16)
    h = hashlib.pbkdf2_hmac("sha256", pw.encode(), salt.encode(), 120_000)
    return salt, h.hex()

def verify_password(pw: str, salt: str, hashed: str) -> bool:
    _, h = hash_password(pw, salt)
    return hmac.compare_digest(h, hashed)

def make_session(username: str) -> str:
    token = secrets.token_urlsafe(32)
    DB["sessions"][token] = {
        "user": username,
        "expires": (datetime.utcnow() + SESSION_TTL).isoformat()
    }
    STORE.mark_dirty()
    return token

# ============================================================
# AUTH
# ============================================================
api_key_header = APIKeyHeader(name="X-API-Key", auto_error=False)

async def require_api_key(api_key: Optional[str] = Depends(api_key_header)):
    if not api_key or api_key != API_KEY:
        raise HTTPException(status_code=403, detail="Invalid or missing API Key")
    return api_key

def get_user_from_session(request: Request):
    token = request.headers.get("X-Session")
    if not token:
        raise HTTPException(status_code=401, detail="No session")
    s = DB["sessions"].get(token)
    if not s:
        raise HTTPException(status_code=401, detail="Invalid session")
    try:
        if datetime.fromisoformat(s["expires"]) < datetime.utcnow():
            del DB["sessions"][token]
            raise HTTPException(status_code=401, detail="Session expired")
    except HTTPException:
        raise
    except Exception:
        raise HTTPException(status_code=401, detail="Invalid session")
    return s["user"]

# ============================================================
# APP
# ============================================================
@asynccontextmanager
async def lifespan(app: FastAPI):
    global DB
    DB = await STORE.load()
    _hydrate_sets()
    await STORE.start()
    log.info("✅ Server started")
    try:
        yield
    finally:
        await STORE.stop()
        log.info("🛑 Server stopped")

app = FastAPI(
    title="🎴 Paskar Advanced Server",
    description="سرور پیشرفته بازی‌های پاسور ایرانی",
    version="2.0.1",
    lifespan=lifespan,
)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"], allow_credentials=True,
    allow_methods=["*"], allow_headers=["*"],
)

# ============================================================
# HOME / HEALTH
# ============================================================
@app.get("/", response_class=HTMLResponse)
async def home():
    return """
    <html><head><title>Paskar Server</title></head>
    <body style="font-family:sans-serif;max-width:800px;margin:auto;padding:20px">
    <h1>🎴 سرور پیشرفته بازی‌های پاسور</h1>
    <p>وضعیت: <b style="color:green">فعال</b></p>
    <ul>
      <li>🎯 چهاربرگ (یازده)</li>
      <li>🎴 هفت خبیث</li>
      <li>💎 شلم (A=10، 10=10، 5=5)</li>
      <li>👑 حکم</li>
    </ul>
    <p>مستندات: <a href="/docs">/docs</a></p>
    </body></html>
    """

@app.get("/health")
async def health():
    return {"status": "ok", "time": now_iso(), "online": len(MANAGER.online)}

# ============================================================
# AUTH ROUTES
# ============================================================
def _public_user(uname: str) -> dict:
    u = DB["users"].get(uname, {})
    return {
        "username": uname,
        "avatar": u.get("avatar", "🙂"),
        "bio": u.get("bio", ""),
        "created_at": u.get("created_at"),
        "last_seen": u.get("last_seen"),
        "stats": u.get("stats", {}),
        "online": uname in MANAGER.online,
        "achievements": list(DB["achievements"].get(uname, set())),
        "friends_count": len(DB["friends"].get(uname, set())),
    }

@app.post("/api/register", status_code=201)
async def register(req: RegisterReq, _=Depends(require_api_key)):
    uname = req.username
    if uname in DB["users"]:
        raise HTTPException(400, "این نام کاربری قبلاً ثبت شده است")
    salt = hashed = None
    if req.password:
        salt, hashed = hash_password(req.password)
    DB["users"][uname] = {
        "user_id": str(uuid.uuid4()),
        "username": uname,
        "salt": salt, "password": hashed,
        "avatar": req.avatar or "🙂",
        "bio": req.bio or "",
        "created_at": now_iso(),
        "last_seen": now_iso(),
        "stats": {
            "games_played": 0, "wins": 0, "losses": 0,
            "per_game": {g: {"played": 0, "wins": 0} for g in GAME_CLASSES},
            "chat_messages": 0,
        },
        "settings": {"notifications": True, "sound": True},
    }
    DB["friends"][uname] = set()
    DB["friend_requests"][uname] = set()
    DB["achievements"][uname] = set()
    token = make_session(uname)
    STORE.mark_dirty()
    log.info(f"👤 Registered: {uname}")
    return {"ok": True, "username": uname, "session": token, "user": _public_user(uname)}

@app.post("/api/login")
async def login(req: LoginReq, _=Depends(require_api_key)):
    u = DB["users"].get(req.username)
    if not u:
        raise HTTPException(404, "کاربر یافت نشد")
    if u.get("password"):
        if not req.password or not verify_password(req.password, u["salt"], u["password"]):
            raise HTTPException(401, "رمز عبور اشتباه است")
    token = make_session(req.username)
    u["last_seen"] = now_iso()
    STORE.mark_dirty()
    return {"ok": True, "session": token, "user": _public_user(req.username)}

@app.post("/api/logout")
async def logout(request: Request, _=Depends(require_api_key)):
    token = request.headers.get("X-Session")
    if token and token in DB["sessions"]:
        del DB["sessions"][token]; STORE.mark_dirty()
    return {"ok": True}

# ============================================================
# USERS
# ============================================================
@app.get("/api/users/me")
async def me(request: Request, _=Depends(require_api_key)):
    uname = get_user_from_session(request)
    return {"user": _public_user(uname)}

@app.get("/api/users/{username}")
async def user_profile(username: str, _=Depends(require_api_key)):
    if username not in DB["users"]:
        raise HTTPException(404, "کاربر یافت نشد")
    return {"user": _public_user(username)}

@app.get("/api/users")
async def list_users(_=Depends(require_api_key), q: Optional[str] = None, limit: int = 50):
    names = list(DB["users"].keys())
    if q:
        ql = q.lower()
        names = [n for n in names if ql in n.lower()]
    names = names[:limit]
    return {"users": [_public_user(n) for n in names], "total": len(names)}

@app.patch("/api/users/me")
async def update_profile(request: Request, data: dict = Body(...), _=Depends(require_api_key)):
    uname = get_user_from_session(request)
    u = DB["users"][uname]
    for k in ("avatar", "bio", "settings"):
        if k in data:
            u[k] = data[k]
    u["last_seen"] = now_iso()
    STORE.mark_dirty()
    return {"ok": True, "user": _public_user(uname)}

# ============================================================
# FRIENDS
# ============================================================
@app.get("/api/friends")
async def list_friends(request: Request, _=Depends(require_api_key)):
    uname = get_user_from_session(request)
    friends = list(DB["friends"].get(uname, set()))
    requests = list(DB["friend_requests"].get(uname, set()))
    return {
        "friends": [_public_user(f) for f in friends],
        "requests": [_public_user(f) for f in requests],
    }

@app.post("/api/friends/request")
async def friend_request(req: FriendReq, request: Request, _=Depends(require_api_key)):
    me = get_user_from_session(request)
    if req.username == me: raise HTTPException(400, "نمی‌توانی به خودت درخواست بدهی")
    if req.username not in DB["users"]: raise HTTPException(404, "کاربر یافت نشد")
    if req.username in DB["friends"].get(me, set()):
        return {"ok": True, "message": "قبلاً دوست هستید"}
    DB["friend_requests"].setdefault(req.username, set()).add(me)
    STORE.mark_dirty()
    await MANAGER.notify_user(req.username, {
        "type": "friend_request", "from": me, "user": _public_user(me)
    })
    return {"ok": True}

@app.post("/api/friends/accept")
async def friend_accept(req: FriendReq, request: Request, _=Depends(require_api_key)):
    me = get_user_from_session(request)
    if req.username not in DB["friend_requests"].get(me, set()):
        raise HTTPException(400, "درخواست موجود نیست")
    DB["friend_requests"][me].discard(req.username)
    DB["friends"].setdefault(me, set()).add(req.username)
    DB["friends"].setdefault(req.username, set()).add(me)
    STORE.mark_dirty()
    if len(DB["friends"][me]) >= 5: grant_achievement(me, "social")
    if len(DB["friends"][req.username]) >= 5: grant_achievement(req.username, "social")
    await MANAGER.notify_user(req.username, {"type": "friend_accept", "user": me})
    return {"ok": True}

@app.delete("/api/friends/{username}")
async def friend_remove(username: str, request: Request, _=Depends(require_api_key)):
    me = get_user_from_session(request)
    DB["friends"].get(me, set()).discard(username)
    DB["friends"].get(username, set()).discard(me)
    STORE.mark_dirty()
    return {"ok": True}

@app.post("/api/friends/block/{username}")
async def block_user(username: str, request: Request, _=Depends(require_api_key)):
    me = get_user_from_session(request)
    DB["blocked"].setdefault(me, set()).add(username)
    STORE.mark_dirty()
    return {"ok": True}

# ============================================================
# NOTIFICATIONS
# ============================================================
@app.get("/api/notifications")
async def get_notifications(request: Request, _=Depends(require_api_key)):
    me = get_user_from_session(request)
    notifs = DB["notifications"].get(me, [])[-50:]
    return {"notifications": notifs, "count": len(notifs)}

@app.post("/api/notifications/read")
async def mark_notifs_read(request: Request, _=Depends(require_api_key)):
    me = get_user_from_session(request)
    DB["notifications"][me] = []
    STORE.mark_dirty()
    return {"ok": True}

# ============================================================
# LEADERBOARD / ACHIEVEMENTS
# ============================================================
@app.get("/api/leaderboard")
async def leaderboard(_=Depends(require_api_key), game: Optional[str] = None, limit: int = 20):
    entries = []
    for uname, u in DB["users"].items():
        stats = u.get("stats", {})
        if game:
            pg = stats.get("per_game", {}).get(game, {"played": 0, "wins": 0})
            entries.append({"username": uname, "avatar": u.get("avatar", "🙂"),
                            "wins": pg.get("wins", 0), "played": pg.get("played", 0)})
        else:
            entries.append({"username": uname, "avatar": u.get("avatar", "🙂"),
                            "wins": stats.get("wins", 0),
                            "played": stats.get("games_played", 0)})
    entries.sort(key=lambda x: (-x["wins"], -x["played"]))
    return {"leaderboard": entries[:limit], "game": game}

@app.get("/api/achievements")
async def list_achievements(_=Depends(require_api_key)):
    return {"achievements": ACHIEVEMENTS}

# ============================================================
# ROOMS
# ============================================================
def _public_room(r: dict, viewer: Optional[str] = None) -> dict:
    rid = r["room_id"]
    ready = r.get("ready")
    if isinstance(ready, set):
        ready_list = list(ready)
    elif isinstance(ready, list):
        ready_list = ready
    else:
        ready_list = []
    return {
        "room_id": rid,
        "name": r["name"],
        "game_type": r["game_type"],
        "host": r["host"],
        "players": list(r.get("players", [])),
        "spectators": list(MANAGER.spectators.get(rid, set())),
        "max_players": r["max_players"],
        "is_private": r["is_private"],
        "has_password": bool(r.get("password_hash")),
        "chat_enabled": r["chat_enabled"],
        "voice_enabled": r["voice_enabled"],
        "allow_spectators": r["allow_spectators"],
        "turn_timeout": r["turn_timeout"],
        "status": r.get("status", "waiting"),
        "ready": ready_list,
        "created_at": r["created_at"],
        "target_score": r.get("target_score"),
    }

@app.get("/api/rooms")
async def list_rooms(request: Request, _=Depends(require_api_key),
                     game: Optional[str] = None):
    me = get_user_from_session(request)
    rooms = []
    for rid, r in DB["rooms"].items():
        if r["is_private"] and r["host"] != me and me not in r.get("players", []):
            continue
        if game and r["game_type"] != game:
            continue
        rooms.append(_public_room(r, me))
    rooms.sort(key=lambda x: x["created_at"], reverse=True)
    return {"rooms": rooms, "total": len(rooms)}

@app.post("/api/rooms", status_code=201)
async def create_room(req: RoomCreateReq, request: Request, _=Depends(require_api_key)):
    me = get_user_from_session(request)
    my_rooms = [r for r in DB["rooms"].values() if r["host"] == me]
    if len(my_rooms) >= MAX_ROOMS_PER_USER:
        raise HTTPException(400, "تعداد اتاق‌های شما به حد مجاز رسیده")
    rid = secrets.token_urlsafe(6)
    pwd_hash = None
    if req.password:
        salt, h = hash_password(req.password)
        pwd_hash = f"{salt}:{h}"
    DB["rooms"][rid] = {
        "room_id": rid,
        "name": req.name,
        "game_type": req.game_type.value,
        "host": me,
        "players": [me],
        "max_players": req.max_players,
        "password_hash": pwd_hash,
        "is_private": req.is_private,
        "chat_enabled": req.chat_enabled,
        "voice_enabled": req.voice_enabled,
        "allow_spectators": req.allow_spectators,
        "turn_timeout": req.turn_timeout,
        "target_score": req.target_score,
        "status": "waiting",
        "ready": {me},
        "created_at": now_iso(),
        "game_instance": None,
    }
    DB["chat_history"][rid] = [{
        "type": "system",
        "message": f"اتاق «{req.name}» توسط {me} ساخته شد",
        "timestamp": now_iso()
    }]
    STORE.mark_dirty()
    log.info(f"🏠 Room created: {rid} by {me}")
    return {"ok": True, "room": _public_room(DB["rooms"][rid])}

@app.get("/api/rooms/{room_id}")
async def get_room(room_id: str, request: Request, _=Depends(require_api_key)):
    me = get_user_from_session(request)
    if room_id not in DB["rooms"]:
        raise HTTPException(404, "اتاق یافت نشد")
    return {"room": _public_room(DB["rooms"][room_id], me)}

@app.post("/api/rooms/{room_id}/join")
async def join_room(room_id: str, request: Request,
                    password: Optional[str] = None, _=Depends(require_api_key)):
    me = get_user_from_session(request)
    r = DB["rooms"].get(room_id)
    if not r:
        raise HTTPException(404, "اتاق یافت نشد")
    if me in r["players"]:
        return {"ok": True, "message": "قبلاً عضو هستید"}
    if r["password_hash"]:
        if not password:
            raise HTTPException(401, "رمز اتاق لازم است")
        salt, h = r["password_hash"].split(":")
        if not verify_password(password, salt, h):
            raise HTTPException(401, "رمز اشتباه است")
    if len(r["players"]) >= r["max_players"]:
        if r["allow_spectators"]:
            MANAGER.spectators[room_id].add(me)
            await MANAGER.broadcast_room(room_id, {"type": "spectator_joined", "username": me})
            return {"ok": True, "as": "spectator"}
        raise HTTPException(400, "اتاق پر است")
    r["players"].append(me)
    if not isinstance(r.get("ready"), set):
        r["ready"] = set(r.get("ready") or [])
    r["ready"].add(me)
    DB["chat_history"].setdefault(room_id, []).append({
        "type": "system", "message": f"{me} به اتاق پیوست", "timestamp": now_iso()
    })
    STORE.mark_dirty()
    await MANAGER.broadcast_room(room_id, {
        "type": "player_joined", "username": me, "room": _public_room(r)
    })
    return {"ok": True, "as": "player"}

@app.post("/api/rooms/{room_id}/leave")
async def leave_room(room_id: str, request: Request, _=Depends(require_api_key)):
    me = get_user_from_session(request)
    r = DB["rooms"].get(room_id)
    if not r:
        return {"ok": True}
    if me in r["players"]:
        r["players"].remove(me)
        if isinstance(r.get("ready"), set):
            r["ready"].discard(me)
    MANAGER.spectators[room_id].discard(me)
    MANAGER.disconnect_room(room_id, me)
    if not r["players"]:
        DB["rooms"].pop(room_id, None)
        DB["chat_history"].pop(room_id, None)
    STORE.mark_dirty()
    await MANAGER.broadcast_room(room_id, {
        "type": "player_left", "username": me
    })
    return {"ok": True}

@app.delete("/api/rooms/{room_id}")
async def delete_room(room_id: str, request: Request, _=Depends(require_api_key)):
    me = get_user_from_session(request)
    r = DB["rooms"].get(room_id)
    if not r:
        raise HTTPException(404, "اتاق یافت نشد")
    if r["host"] != me:
        raise HTTPException(403, "فقط میزبان می‌تواند حذف کند")
    await MANAGER.broadcast_room(room_id, {"type": "room_closed"})
    DB["rooms"].pop(room_id, None)
    DB["chat_history"].pop(room_id, None)
    STORE.mark_dirty()
    return {"ok": True}

@app.post("/api/rooms/{room_id}/ready")
async def toggle_ready(room_id: str, request: Request, _=Depends(require_api_key)):
    me = get_user_from_session(request)
    r = DB["rooms"].get(room_id)
    if not r or me not in r["players"]:
        raise HTTPException(404, "اتاق یافت نشد")
    if not isinstance(r.get("ready"), set):
        r["ready"] = set(r.get("ready") or [])
    if me in r["ready"]:
        r["ready"].discard(me)
    else:
        r["ready"].add(me)
    STORE.mark_dirty()
    await MANAGER.broadcast_room(room_id, {"type": "ready_update", "ready": list(r["ready"])})
    return {"ok": True, "ready": me in r["ready"]}

@app.post("/api/rooms/{room_id}/kick")
async def kick_player(room_id: str, target: str, request: Request, _=Depends(require_api_key)):
    me = get_user_from_session(request)
    r = DB["rooms"].get(room_id)
    if not r or r["host"] != me:
        raise HTTPException(403, "فقط میزبان می‌تواند اخراج کند")
    if target in r["players"] and target != me:
        r["players"].remove(target)
        if isinstance(r.get("ready"), set):
            r["ready"].discard(target)
        await MANAGER.send_room(room_id, target, {"type": "kicked", "by": me})
        await MANAGER.broadcast_room(room_id, {"type": "player_left", "username": target})
        STORE.mark_dirty()
    return {"ok": True}

async def _do_start_game(room_id: str, me: str):
    r = DB["rooms"].get(room_id)
    if not r:
        raise HTTPException(404, "اتاق یافت نشد")
    if me != r["host"]:
        raise HTTPException(403, "فقط میزبان می‌تواند بازی را شروع کند")
    gt = r["game_type"]
    players = list(r["players"])
    min_p = {"chahar_barg": 2, "haft_khabis": 2, "shelem": 4, "hokm": 4}[gt]
    if len(players) < min_p:
        raise HTTPException(400, f"بازی {gt} حداقل {min_p} بازیکن نیاز دارد")
    if not set(players).issubset(set(r.get("ready", set()))):
        raise HTTPException(400, "همه بازیکنان باید آماده باشند")
    cls = GAME_CLASSES[gt]
    opts = {"turn_timeout": r["turn_timeout"]}
    if gt == "shelem" and r.get("target_score"):
        opts["target_score"] = r["target_score"]
    game = cls(players, opts)
    game.start()
    r["game_instance"] = game
    r["status"] = "playing"
    r["started_at"] = now_iso()
    for p in players:
        u = DB["users"].get(p)
        if u:
            st = u["stats"]
            st["games_played"] = st.get("games_played", 0) + 1
            st.setdefault("per_game", {}).setdefault(gt, {"played": 0, "wins": 0})
            st["per_game"][gt]["played"] += 1
            if st["games_played"] >= 50:
                grant_achievement(p, "veteran")
    STORE.mark_dirty()
    await MANAGER.broadcast_room(room_id, {
        "type": "game_started", "game_type": gt,
        "state": game.public_state(),
    })
    for p in players:
        await MANAGER.send_room(room_id, p, {
            "type": "personal_state", "state": game.personal_state(p)
        })
    _start_turn_timer(room_id)
    return {"ok": True}

@app.post("/api/rooms/{room_id}/start")
async def start_game(room_id: str, request: Request, _=Depends(require_api_key)):
    me = get_user_from_session(request)
    return await _do_start_game(room_id, me)

# ============================================================
# TURN TIMER
# ============================================================
def _start_turn_timer(room_id: str):
    old = MANAGER.turn_tasks.get(room_id)
    if old and not old.done():
        old.cancel()

    async def _loop():
        try:
            while True:
                await asyncio.sleep(1)
                r = DB["rooms"].get(room_id)
                if not r or r.get("status") != "playing":
                    break
                game = r.get("game_instance")
                if not game or game.finished:
                    break
                await MANAGER.broadcast_room(room_id, {
                    "type": "tick",
                    "time_left": game.time_left(),
                    "current_turn": game.players[game.current_turn] if not game.finished else None
                })
                if game.is_turn_expired() and not game.finished:
                    cu = game.players[game.current_turn]
                    result = game.auto_play(cu)
                    await MANAGER.broadcast_room(room_id, {
                        "type": "auto_played", "username": cu,
                        "state": game.public_state()
                    })
                    for p in game.players:
                        await MANAGER.send_room(room_id, p, {
                            "type": "personal_state",
                            "state": game.personal_state(p)
                        })
                    if game.finished:
                        await _on_game_finished(room_id, game)
                        break
        except asyncio.CancelledError:
            pass
        except Exception as e:
            log.error(f"Turn timer error in {room_id}: {e}")

    MANAGER.turn_tasks[room_id] = asyncio.create_task(_loop())

async def _on_game_finished(room_id: str, game: BaseGame):
    r = DB["rooms"].get(room_id)
    if not r:
        return
    r["status"] = "finished"
    r["finished_at"] = now_iso()
    gt = r["game_type"]
    for p in game.players:
        u = DB["users"].get(p)
        if not u:
            continue
        won = p in game.winners
        if won:
            u["stats"]["wins"] = u["stats"].get("wins", 0) + 1
            u["stats"].setdefault("per_game", {}).setdefault(gt, {"played": 0, "wins": 0})
            u["stats"]["per_game"][gt]["wins"] += 1
        else:
            u["stats"]["losses"] = u["stats"].get("losses", 0) + 1
        if won:
            grant_achievement(p, "first_win")
            wins = u["stats"]["per_game"].get(gt, {}).get("wins", 0)
            mapping = {"chahar_barg": "chahar_master", "hokm": "hokm_king",
                       "shelem": "shelem_pro", "haft_khabis": "haft_champ"}
            if wins >= 10 and gt in mapping:
                grant_achievement(p, mapping[gt])
    hist = DB["game_history"].setdefault(room_id, [])
    hist.append({
        "game_type": gt,
        "players": game.players,
        "winners": game.winners,
        "moves": game.moves[-200:],
        "finished_at": now_iso(),
    })
    if len(hist) > 20:
        DB["game_history"][room_id] = hist[-20:]
    STORE.mark_dirty()
    await MANAGER.broadcast_room(room_id, {
        "type": "game_over",
        "winners": game.winners,
        "state": game.public_state(),
    })
    for p in game.players:
        notif = {
            "type": "game_result", "room": room_id, "game_type": gt,
            "won": p in game.winners, "timestamp": now_iso(),
            "title": "🏆 بردی!" if p in game.winners else "😔 باختی",
            "body": f"بازی {gt} در اتاق {r['name']}"
        }
        DB["notifications"].setdefault(p, []).append(notif)
        await MANAGER.notify_user(p, notif)
    STORE.mark_dirty()

# ============================================================
# CHAT / HISTORY
# ============================================================
@app.get("/api/rooms/{room_id}/chat")
async def get_chat(room_id: str, request: Request,
                   _=Depends(require_api_key), limit: int = 100):
    get_user_from_session(request)
    if room_id not in DB["rooms"]:
        raise HTTPException(404, "اتاق یافت نشد")
    return {"messages": DB["chat_history"].get(room_id, [])[-limit:]}

@app.get("/api/rooms/{room_id}/history")
async def get_history(room_id: str, request: Request, _=Depends(require_api_key)):
    get_user_from_session(request)
    return {"history": DB["game_history"].get(room_id, [])}

# ============================================================
# WEBSOCKET: ROOM (اصلاح شده)
# ============================================================
@app.websocket("/ws/room/{room_id}")
async def ws_room(websocket: WebSocket, room_id: str,
                  username: str = Query(...), api_key: str = Query(...),
                  token: str = Query(...)):
    # ۱. اول اتصال را می‌پذیریم تا Handshake وب‌سوکت کامل شود
    await websocket.accept()

    # ۲. حالا اعتبارسنجی‌ها را انجام می‌دهیم
    if api_key != API_KEY:
        await websocket.send_json({"type": "error", "message": "API Key نامعتبر است"})
        await websocket.close(code=1008, reason="Invalid API Key")
        return

    s = DB["sessions"].get(token)
    if not s or s["user"] != username:
        await websocket.send_json({"type": "error", "message": "نشست شما منقضی شده است. دوباره وارد شوید."})
        await websocket.close(code=1008, reason="Invalid session")
        return

    if room_id not in DB["rooms"]:
        await websocket.send_json({"type": "error", "message": "اتاق پیدا نشد. ممکن است حذف شده باشد."})
        await websocket.close(code=1008, reason="Room not found")
        return

    r = DB["rooms"][room_id]
    is_player = username in r["players"]
    is_spec = username in MANAGER.spectators.get(room_id, set())

    if not (is_player or is_spec):
        await websocket.send_json({"type": "error", "message": "شما در این اتاق عضو نیستید."})
        await websocket.close(code=1008, reason="Not in room")
        return

    # ادامه کدهای قبلی...
    await MANAGER.connect_room(room_id, username, websocket, spectator=is_spec)
    MANAGER.online.add(username)

    try:
        await websocket.send_json({
            "type": "welcome", "room": _public_room(r, username),
            "you": username, "is_spectator": is_spec,
        })
        if is_player and r.get("game_instance"):
            game = r["game_instance"]
            await websocket.send_json({
                "type": "personal_state",
                "state": game.personal_state(username)
            })
        await websocket.send_json({
            "type": "chat_history",
            "messages": DB["chat_history"].get(room_id, [])[-100:]
        })
    except Exception:
        pass

    await MANAGER.broadcast_room(room_id, {
        "type": "user_online", "username": username, "spectator": is_spec
    }, exclude=username)

    try:
        while True:
            msg = await websocket.receive_json()
            await _handle_ws_message(room_id, username, websocket, msg)
    except WebSocketDisconnect:
        pass
    except Exception as e:
        log.warning(f"WS error {username}: {e}")
    finally:
        MANAGER.disconnect_room(room_id, username)
        MANAGER.online.discard(username)
        await MANAGER.broadcast_room(room_id, {"type": "user_offline", "username": username})

async def _handle_ws_message(room_id: str, username: str, ws: WebSocket, msg: dict):
    r = DB["rooms"].get(room_id)
    if not r:
        return
    t = msg.get("type")

    if t in ("chat", "voice", "typing", "emote"):
        if MANAGER.is_rate_limited(username):
            await ws.send_json({"type": "error", "message": "خیلی سریع! کمی صبر کن"})
            return

    if t == "chat":
        text = (msg.get("message") or "").strip()[:500]
        if not text:
            return
        if not r["chat_enabled"]:
            await ws.send_json({"type": "error", "message": "چت این اتاق غیرفعال است"})
            return
        if text.startswith("/"):
            return await _handle_chat_command(room_id, username, ws, text, r)
        chat = {
            "type": "chat", "username": username, "message": text,
            "timestamp": now_iso(),
        }
        DB["chat_history"].setdefault(room_id, []).append(chat)
        if len(DB["chat_history"][room_id]) > MAX_CHAT_HISTORY:
            DB["chat_history"][room_id] = DB["chat_history"][room_id][-MAX_CHAT_HISTORY:]
        u = DB["users"].get(username)
        if u:
            u["stats"]["chat_messages"] = u["stats"].get("chat_messages", 0) + 1
            if u["stats"]["chat_messages"] >= 100:
                grant_achievement(username, "chatty")
        STORE.mark_dirty()
        await MANAGER.broadcast_room(room_id, chat)

    elif t == "whisper":
        to = msg.get("to")
        text = (msg.get("message") or "").strip()[:500]
        if not to or not text:
            return
        await MANAGER.send_room(room_id, to, {
            "type": "chat", "username": username, "message": text,
            "timestamp": now_iso(), "private": True, "to": to
        })
        await ws.send_json({
            "type": "chat", "username": username, "message": text,
            "timestamp": now_iso(), "private": True, "to": to
        })

    elif t == "typing":
        MANAGER.typing[room_id].add(username)
        await MANAGER.broadcast_room(room_id, {"type": "typing", "username": username},
                                     exclude=username)

    elif t == "emote":
        emoji = msg.get("emoji", "👍")
        await MANAGER.broadcast_room(room_id, {
            "type": "emote", "username": username, "emoji": emoji
        })

    elif t == "voice":
        if not r["voice_enabled"]:
            return
        await MANAGER.broadcast_room(room_id, {
            "type": "voice", "username": username,
            "data": msg.get("data", ""),
            "mime": msg.get("mime", "audio/webm"),
        }, exclude=username)

    elif t in ("webrtc_offer", "webrtc_answer", "webrtc_ice"):
        target = msg.get("target")
        if not target:
            return
        await MANAGER.send_room(room_id, target, {
            "type": t, "from": username, "payload": msg.get("payload")
        })

    elif t == "ready":
        if username not in r["players"]:
            return
        if not isinstance(r.get("ready"), set):
            r["ready"] = set(r.get("ready") or [])
        if username in r["ready"]:
            r["ready"].discard(username)
        else:
            r["ready"].add(username)
        STORE.mark_dirty()
        await MANAGER.broadcast_room(room_id, {"type": "ready_update", "ready": list(r["ready"])})

    elif t == "game_action":
        game = r.get("game_instance")
        if not game or game.finished:
            await ws.send_json({"type": "error", "message": "بازی فعال نیست"})
            return
        if username not in game.players:
            await ws.send_json({"type": "error", "message": "تماشاچی نمی‌تواند بازی کند"})
            return
        action = msg.get("action")
        data = msg.get("data", {}) or {}
        result = None
        try:
            if action == "play_card":
                result = game.play_card(username, int(data.get("card_index", -1)))
            elif action == "bid" and game.game_type == "shelem":
                result = game.place_bid(username, data.get("amount"))
            elif action == "select_hokm":
                result = game.select_hokm(username, data.get("suit"))
            elif action == "play_hokm":
                result = game.play_card(username, int(data.get("card_index", -1)))
            elif action == "auto":
                result = game.auto_play(username)
            elif action == "state":
                result = {"ok": True}
        except Exception as e:
            await ws.send_json({"type": "error", "message": str(e)})
            return
        if result and result.get("error"):
            await ws.send_json({"type": "error", "message": result["error"]})
            return
        await MANAGER.broadcast_room(room_id, {
            "type": "game_update",
            "state": game.public_state(),
            "action": action, "by": username,
        })
        for p in game.players:
            await MANAGER.send_room(room_id, p, {
                "type": "personal_state", "state": game.personal_state(p)
            })
        if game.finished:
            await _on_game_finished(room_id, game)

    elif t == "ping":
        await ws.send_json({"type": "pong", "t": time.time()})

async def _handle_chat_command(room_id: str, username: str, ws: WebSocket, text: str, r: dict):
    parts = text.split()
    cmd = parts[0].lower()
    args = parts[1:]

    if cmd == "/help":
        await ws.send_json({"type": "chat", "username": "system", "message":
            "دستورات: /me | /whisper <user> <msg> | /roll | /kick <user> | /ready | /start"})
    elif cmd == "/me":
        action = " ".join(args)[:200]
        await MANAGER.broadcast_room(room_id, {
            "type": "chat", "username": "system",
            "message": f"* {username} {action}", "timestamp": now_iso()
        })
    elif cmd == "/whisper" and len(args) >= 2:
        to = args[0]
        m = " ".join(args[1:])[:300]
        await MANAGER.send_room(room_id, to, {
            "type": "chat", "username": username, "message": m,
            "private": True, "to": to
        })
        await ws.send_json({
            "type": "chat", "username": username, "message": m,
            "private": True, "to": to
        })
    elif cmd == "/roll":
        n = random.randint(1, 6)
        await MANAGER.broadcast_room(room_id, {
            "type": "chat", "username": "system",
            "message": f"🎲 {username} تاس ریخت: {n}"
        })
    elif cmd == "/kick" and args:
        if username == r["host"] and args[0] in r["players"]:
            target = args[0]
            r["players"].remove(target)
            if isinstance(r.get("ready"), set):
                r["ready"].discard(target)
            await MANAGER.send_room(room_id, target, {"type": "kicked", "by": username})
            await MANAGER.broadcast_room(room_id, {"type": "player_left", "username": target})
            STORE.mark_dirty()
    elif cmd == "/ready":
        if username in r["players"]:
            if not isinstance(r.get("ready"), set):
                r["ready"] = set(r.get("ready") or [])
            if username in r["ready"]:
                r["ready"].discard(username)
            else:
                r["ready"].add(username)
            STORE.mark_dirty()
            await MANAGER.broadcast_room(room_id, {
                "type": "ready_update", "ready": list(r["ready"])
            })
    elif cmd == "/start":
        if username == r["host"]:
            try:
                await _do_start_game(room_id, username)
            except HTTPException as he:
                await ws.send_json({"type": "error", "message": he.detail})
            except Exception as e:
                await ws.send_json({"type": "error", "message": str(e)})
    else:
        await ws.send_json({"type": "error", "message": f"دستور ناشناخته: {cmd}"})

# ============================================================
# WEBSOCKET: USER (NOTIFICATIONS) - اصلاح شده
# ============================================================
@app.websocket("/ws/user")
async def ws_user(websocket: WebSocket, username: str = Query(...),
                  api_key: str = Query(...), token: str = Query(...)):
    # ۱. اول اتصال را می‌پذیریم
    await websocket.accept()

    # ۲. سپس اعتبارسنجی
    if api_key != API_KEY:
        await websocket.send_json({"type": "error", "message": "API Key نامعتبر است"})
        await websocket.close(code=1008, reason="Invalid API Key")
        return

    s = DB["sessions"].get(token)
    if not s or s["user"] != username:
        await websocket.send_json({"type": "error", "message": "نشست شما منقضی شده است. دوباره وارد شوید."})
        await websocket.close(code=1008, reason="Invalid session")
        return

    # ادامه کدهای قبلی...
    await MANAGER.connect_user(username, websocket)
    try:
        await websocket.send_json({"type": "hello", "username": username})
        while True:
            msg = await websocket.receive_json()
            if msg.get("type") == "ping":
                await websocket.send_json({"type": "pong"})
    except WebSocketDisconnect:
        pass
    except Exception:
        pass
    finally:
        MANAGER.disconnect_user(username)

# ============================================================
# ADMIN
# ============================================================
@app.get("/api/admin/stats")
async def admin_stats(request: Request, _=Depends(require_api_key)):
    get_user_from_session(request)
    return {
        "users": len(DB["users"]),
        "rooms": len(DB["rooms"]),
        "online": len(MANAGER.online),
        "sessions": len(DB["sessions"]),
        "games_history": sum(len(v) for v in DB["game_history"].values()),
    }

# ============================================================
# MAIN
# ============================================================
if __name__ == "__main__":
    print("\n" + "=" * 60)
    print("🎴  Paskar Advanced Server (v2.0.1 — Fixed)")
    print("=" * 60)
    print(f"🔑  API Key prefix: {API_KEY[:8]}...")
    print(f"💾  DB path: {DB_PATH}")
    print(f"⏱️   Turn timeout: {TURN_TIMEOUT}s")
    print(f"🌐  http://0.0.0.0:8000")
    print("=" * 60 + "\n")
    uvicorn.run(app, host="0.0.0.0", port=8000, log_level="info")