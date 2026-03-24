from dataclasses import dataclass


@dataclass
class Guest:
    id: str
    name: str
    email: str


@dataclass
class Reservation:
    id: str
    guest_id: str
    unit_id: str
    check_in: str
    check_out: str
    status: str  # "confirmed" or "cancelled"
