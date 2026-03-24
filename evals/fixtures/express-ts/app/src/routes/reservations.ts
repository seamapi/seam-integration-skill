import { Router, Request, Response } from "express";
import {
  createReservation,
  updateReservation,
  cancelReservation,
  getReservation,
} from "../services/reservationService";

const router = Router();

router.post("/", (req: Request, res: Response) => {
  try {
    const { guestName, guestEmail, unitId, checkIn, checkOut } = req.body;

    if (!guestName || !guestEmail || !unitId || !checkIn || !checkOut) {
      res.status(400).json({
        error: "Missing required fields: guestName, guestEmail, unitId, checkIn, checkOut",
      });
      return;
    }

    const reservation = createReservation({
      guestName,
      guestEmail,
      unitId,
      checkIn,
      checkOut,
    });

    res.status(201).json({ reservation });
  } catch (err: any) {
    if (err.message?.includes("not found")) {
      res.status(404).json({ error: err.message });
    } else {
      res.status(400).json({ error: err.message });
    }
  }
});

router.put("/:id", (req: Request, res: Response) => {
  try {
    const { checkIn, checkOut } = req.body;
    const reservation = updateReservation(req.params.id, { checkIn, checkOut });
    res.status(200).json({ reservation });
  } catch (err: any) {
    if (err.message?.includes("not found")) {
      res.status(404).json({ error: err.message });
    } else {
      res.status(400).json({ error: err.message });
    }
  }
});

router.delete("/:id", (req: Request, res: Response) => {
  try {
    const reservation = cancelReservation(req.params.id);
    res.status(200).json({ reservation });
  } catch (err: any) {
    if (err.message?.includes("not found")) {
      res.status(404).json({ error: err.message });
    } else {
      res.status(400).json({ error: err.message });
    }
  }
});

router.get("/:id", (req: Request, res: Response) => {
  try {
    const reservation = getReservation(req.params.id);
    res.status(200).json({ reservation });
  } catch (err: any) {
    if (err.message?.includes("not found")) {
      res.status(404).json({ error: err.message });
    } else {
      res.status(400).json({ error: err.message });
    }
  }
});

export default router;
