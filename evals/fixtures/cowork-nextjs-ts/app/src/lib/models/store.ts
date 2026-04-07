import { Member, Room, Booking } from "./types";

let idCounter = 0;

export function generateId(): string {
  idCounter++;
  return `id-${Date.now()}-${idCounter}`;
}

export const store = {
  members: [] as Member[],
  rooms: [
    { id: "room-a1", name: "Focus Room A1", capacity: 1, floor: 1 },
    { id: "room-b2", name: "Meeting Room B2", capacity: 6, floor: 2 },
    { id: "room-c3", name: "Board Room C3", capacity: 12, floor: 3 },
  ] as Room[],
  bookings: [] as Booking[],
};

export function findRoom(id: string): Room | undefined {
  return store.rooms.find((r) => r.id === id);
}

export function findMember(id: string): Member | undefined {
  return store.members.find((m) => m.id === id);
}
