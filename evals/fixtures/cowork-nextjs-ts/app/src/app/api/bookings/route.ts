import { NextRequest, NextResponse } from "next/server";
import { createBooking } from "@/lib/services/bookingService";

export async function POST(request: NextRequest) {
  try {
    const body = await request.json();
    const { memberName, memberEmail, memberCompany, roomId, startTime, endTime } =
      body;

    if (
      !memberName ||
      !memberEmail ||
      !memberCompany ||
      !roomId ||
      !startTime ||
      !endTime
    ) {
      return NextResponse.json(
        {
          error:
            "Missing required fields: memberName, memberEmail, memberCompany, roomId, startTime, endTime",
        },
        { status: 400 }
      );
    }

    const booking = createBooking({
      memberName,
      memberEmail,
      memberCompany,
      roomId,
      startTime,
      endTime,
    });

    return NextResponse.json({ booking }, { status: 201 });
  } catch (err: any) {
    if (err.message?.includes("not found")) {
      return NextResponse.json({ error: err.message }, { status: 404 });
    }
    return NextResponse.json({ error: err.message }, { status: 400 });
  }
}
