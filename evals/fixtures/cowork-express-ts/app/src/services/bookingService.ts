import { RoomBooking } from "../models/types";
import { store, generateId, findRoom } from "../models/store";

export function createBooking(data: {
  memberName: string;
  memberEmail: string;
  memberCompany: string;
  roomId: string;
  startTime: string;
  endTime: string;
}): RoomBooking {
  const room = findRoom(data.roomId);
  if (!room) {
    throw new Error(`Room not found: ${data.roomId}`);
  }

  // Find existing member by email or create a new one
  let member = store.members.find((m) => m.email === data.memberEmail);
  if (!member) {
    member = {
      id: generateId(),
      name: data.memberName,
      email: data.memberEmail,
      company: data.memberCompany,
    };
    store.members.push(member);
  }

  const booking: RoomBooking = {
    id: generateId(),
    memberId: member.id,
    roomId: data.roomId,
    startTime: data.startTime,
    endTime: data.endTime,
    status: "active",
  };

  store.bookings.push(booking);
  return booking;
}

export function updateBooking(
  id: string,
  data: { startTime?: string; endTime?: string }
): RoomBooking {
  const booking = store.bookings.find((b) => b.id === id);
  if (!booking) {
    throw new Error(`Booking not found: ${id}`);
  }

  if (data.startTime !== undefined) {
    booking.startTime = data.startTime;
  }
  if (data.endTime !== undefined) {
    booking.endTime = data.endTime;
  }

  return booking;
}

export function cancelBooking(id: string): RoomBooking {
  const booking = store.bookings.find((b) => b.id === id);
  if (!booking) {
    throw new Error(`Booking not found: ${id}`);
  }

  booking.status = "cancelled";
  return booking;
}

export function getBooking(id: string): RoomBooking {
  const booking = store.bookings.find((b) => b.id === id);
  if (!booking) {
    throw new Error(`Booking not found: ${id}`);
  }

  return booking;
}
