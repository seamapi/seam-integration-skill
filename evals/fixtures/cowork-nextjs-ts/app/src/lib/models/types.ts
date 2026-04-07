export interface Member {
  id: string;
  name: string;
  email: string;
  company: string;
}

export interface Room {
  id: string;
  name: string;
  capacity: number;
  floor: number;
}

export interface Booking {
  id: string;
  memberId: string;
  roomId: string;
  startTime: string;
  endTime: string;
  status: "active" | "cancelled";
}
