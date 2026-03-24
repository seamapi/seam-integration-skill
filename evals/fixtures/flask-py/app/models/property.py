from dataclasses import dataclass


@dataclass
class Property:
    id: str
    name: str
    address: str


@dataclass
class Unit:
    id: str
    property_id: str
    name: str
