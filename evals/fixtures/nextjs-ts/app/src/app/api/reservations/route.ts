import { NextRequest, NextResponse } from "next/server";
import { createReservation } from "@/lib/services/reservationService";

export async function POST(request: NextRequest) {
  try {
    const body = await request.json();
    const { guestName, guestEmail, unitId, checkIn, checkOut } = body;

    if (!guestName || !guestEmail || !unitId || !checkIn || !checkOut) {
      return NextResponse.json(
        {
          error:
            "Missing required fields: guestName, guestEmail, unitId, checkIn, checkOut",
        },
        { status: 400 }
      );
    }

    const reservation = createReservation({
      guestName,
      guestEmail,
      unitId,
      checkIn,
      checkOut,
    });

    return NextResponse.json({ reservation }, { status: 201 });
  } catch (err: any) {
    if (err.message?.includes("not found")) {
      return NextResponse.json({ error: err.message }, { status: 404 });
    }
    return NextResponse.json({ error: err.message }, { status: 400 });
  }
}
