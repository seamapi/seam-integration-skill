<?php

namespace App\Models;

class Store
{
    private static string $filePath = '/tmp/hotel_store.json';

    private static function load(): array
    {
        if (!file_exists(self::$filePath)) {
            return [
                'idCounter' => 0,
                'guests' => [],
                'rooms' => [
                    ['id' => 'room-101', 'number' => '101', 'floor' => 1, 'type' => 'standard'],
                    ['id' => 'room-205', 'number' => '205', 'floor' => 2, 'type' => 'suite'],
                    ['id' => 'room-ph1', 'number' => 'PH1', 'floor' => 10, 'type' => 'penthouse'],
                ],
                'bookings' => [],
            ];
        }

        return json_decode(file_get_contents(self::$filePath), true);
    }

    private static function save(array $data): void
    {
        file_put_contents(self::$filePath, json_encode($data));
    }

    public static function generateId(): string
    {
        $data = self::load();
        $data['idCounter']++;
        self::save($data);
        return 'id-' . time() . '-' . $data['idCounter'];
    }

    public static function getGuests(): array
    {
        return self::load()['guests'];
    }

    public static function addGuest(array $guest): void
    {
        $data = self::load();
        $data['guests'][] = $guest;
        self::save($data);
    }

    public static function getBookings(): array
    {
        return self::load()['bookings'];
    }

    public static function addBooking(array $booking): void
    {
        $data = self::load();
        $data['bookings'][] = $booking;
        self::save($data);
    }

    public static function updateBookingById(string $id, callable $updater): ?array
    {
        $data = self::load();
        foreach ($data['bookings'] as &$booking) {
            if ($booking['id'] === $id) {
                $booking = $updater($booking);
                self::save($data);
                return $booking;
            }
        }
        return null;
    }

    public static function findRoom(string $id): ?array
    {
        $data = self::load();
        foreach ($data['rooms'] as $room) {
            if ($room['id'] === $id) {
                return $room;
            }
        }
        return null;
    }

    public static function findGuest(string $id): ?array
    {
        $data = self::load();
        foreach ($data['guests'] as $guest) {
            if ($guest['id'] === $id) {
                return $guest;
            }
        }
        return null;
    }

    public static function findBooking(string $id): ?array
    {
        $data = self::load();
        foreach ($data['bookings'] as $booking) {
            if ($booking['id'] === $id) {
                return $booking;
            }
        }
        return null;
    }
}
