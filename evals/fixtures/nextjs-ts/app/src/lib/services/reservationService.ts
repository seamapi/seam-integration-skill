import { Reservation } from "../models/types";
import { store, generateId, findUnit } from "../models/store";

export function createReservation(data: {
  guestName: string;
  guestEmail: string;
  unitId: string;
  checkIn: string;
  checkOut: string;
}): Reservation {
  const unit = findUnit(data.unitId);
  if (!unit) {
    throw new Error(`Unit not found: ${data.unitId}`);
  }

  // Find existing guest by email or create a new one
  let guest = store.guests.find((g) => g.email === data.guestEmail);
  if (!guest) {
    guest = {
      id: generateId(),
      name: data.guestName,
      email: data.guestEmail,
    };
    store.guests.push(guest);
  }

  const reservation: Reservation = {
    id: generateId(),
    guestId: guest.id,
    unitId: data.unitId,
    checkIn: data.checkIn,
    checkOut: data.checkOut,
    status: "confirmed",
  };

  store.reservations.push(reservation);
  return reservation;
}

export function updateReservation(
  id: string,
  data: { checkIn?: string; checkOut?: string }
): Reservation {
  const reservation = store.reservations.find((r) => r.id === id);
  if (!reservation) {
    throw new Error(`Reservation not found: ${id}`);
  }

  if (data.checkIn !== undefined) {
    reservation.checkIn = data.checkIn;
  }
  if (data.checkOut !== undefined) {
    reservation.checkOut = data.checkOut;
  }

  return reservation;
}

export function cancelReservation(id: string): Reservation {
  const reservation = store.reservations.find((r) => r.id === id);
  if (!reservation) {
    throw new Error(`Reservation not found: ${id}`);
  }

  reservation.status = "cancelled";
  return reservation;
}

export function getReservation(id: string): Reservation {
  const reservation = store.reservations.find((r) => r.id === id);
  if (!reservation) {
    throw new Error(`Reservation not found: ${id}`);
  }

  return reservation;
}
