from dataclasses import dataclass


@dataclass
class Room:
    id: str
    name: str
    capacity: int
    floor: int
