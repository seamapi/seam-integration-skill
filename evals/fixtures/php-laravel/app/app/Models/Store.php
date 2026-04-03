<?php

namespace App\Models;

class Store
{
    private static string $filePath = '/tmp/pms_store.json';

    private static function load(): array
    {
        if (!file_exists(self::$filePath)) {
            return [
                'idCounter' => 0,
                'guests' => [],
                'properties' => [
                    [
                        'id' => 'prop-1',
                        'name' => 'Sunset Rentals',
                        'address' => '123 Sunset Blvd, Los Angeles, CA 90028',
                    ],
                ],
                'units' => [
                    ['id' => 'unit-101', 'property_id' => 'prop-1', 'name' => 'Unit 101'],
                    ['id' => 'unit-202', 'property_id' => 'prop-1', 'name' => 'Unit 202'],
                ],
                'reservations' => [],
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

    public static function getReservations(): array
    {
        return self::load()['reservations'];
    }

    public static function addReservation(array $reservation): void
    {
        $data = self::load();
        $data['reservations'][] = $reservation;
        self::save($data);
    }

    public static function updateReservationById(string $id, callable $updater): ?array
    {
        $data = self::load();
        foreach ($data['reservations'] as &$reservation) {
            if ($reservation['id'] === $id) {
                $reservation = $updater($reservation);
                self::save($data);
                return $reservation;
            }
        }
        return null;
    }

    public static function findUnit(string $id): ?array
    {
        $data = self::load();
        foreach ($data['units'] as $unit) {
            if ($unit['id'] === $id) {
                return $unit;
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

    public static function findReservation(string $id): ?array
    {
        $data = self::load();
        foreach ($data['reservations'] as $reservation) {
            if ($reservation['id'] === $id) {
                return $reservation;
            }
        }
        return null;
    }
}
