import uuid

from models.property import Property, Unit
from models.reservation import Guest, Reservation

# In-memory data store
properties = [
    Property(id="prop-1", name="Sunset Rentals", address="123 Sunset Blvd"),
]

units = [
    Unit(id="unit-101", property_id="prop-1", name="Unit 101"),
    Unit(id="unit-202", property_id="prop-1", name="Unit 202"),
]

guests: list[Guest] = []

reservations: list[Reservation] = []


def generate_id() -> str:
    return str(uuid.uuid4())


def find_unit(unit_id: str) -> Unit | None:
    return next((u for u in units if u.id == unit_id), None)


def find_guest(guest_id: str) -> Guest | None:
    return next((g for g in guests if g.id == guest_id), None)
