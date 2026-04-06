<?php

namespace App\Services;

use App\Models\Store;

class BookingService
{
    public static function createBooking(array $data): array
    {
        $room = Store::findRoom($data['room_id'] ?? '');
        if (!$room) {
            throw new \InvalidArgumentException("Room not found: " . ($data['room_id'] ?? ''));
        }

        // Find existing guest by email or create a new one
        $guest = null;
        foreach (Store::getGuests() as $g) {
            if ($g['email'] === ($data['guest_email'] ?? '')) {
                $guest = $g;
                break;
            }
        }

        if (!$guest) {
            $guest = [
                'id' => Store::generateId(),
                'name' => $data['guest_name'] ?? '',
                'email' => $data['guest_email'] ?? '',
                'phone' => $data['guest_phone'] ?? '',
            ];
            Store::addGuest($guest);
        }

        $booking = [
            'id' => Store::generateId(),
            'guest_id' => $guest['id'],
            'room_id' => $data['room_id'],
            'check_in' => $data['check_in'],
            'check_out' => $data['check_out'],
            'status' => 'confirmed',
        ];

        Store::addBooking($booking);

        return $booking;
    }

    public static function updateBooking(string $id, array $data): array
    {
        $result = Store::updateBookingById($id, function (array $booking) use ($data) {
            if (isset($data['check_in'])) {
                $booking['check_in'] = $data['check_in'];
            }
            if (isset($data['check_out'])) {
                $booking['check_out'] = $data['check_out'];
            }
            return $booking;
        });

        if (!$result) {
            throw new \InvalidArgumentException("Booking not found: {$id}");
        }

        return $result;
    }

    public static function cancelBooking(string $id): array
    {
        $result = Store::updateBookingById($id, function (array $booking) {
            $booking['status'] = 'cancelled';
            return $booking;
        });

        if (!$result) {
            throw new \InvalidArgumentException("Booking not found: {$id}");
        }

        return $result;
    }

    public static function getBooking(string $id): array
    {
        $booking = Store::findBooking($id);

        if (!$booking) {
            throw new \InvalidArgumentException("Booking not found: {$id}");
        }

        return $booking;
    }
}
