from dataclasses import dataclass


@dataclass
class Member:
    id: str
    name: str
    email: str
    company: str


@dataclass
class RoomBooking:
    id: str
    member_id: str
    room_id: str
    start_time: str
    end_time: str
    status: str  # "active" or "cancelled"
