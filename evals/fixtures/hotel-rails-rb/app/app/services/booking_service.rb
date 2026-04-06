class BookingService
  class << self
    def create_booking(data)
      room = Store.find_room(data[:room_id])
      raise "Room not found: #{data[:room_id]}" unless room

      # Find existing guest by email or create a new one
      guest = Store.guests.find { |g| g[:email] == data[:guest_email] }
      unless guest
        guest = {
          id: Store.generate_id,
          name: data[:guest_name],
          email: data[:guest_email],
          phone: data[:guest_phone]
        }
        Store.guests << guest
      end

      booking = {
        id: Store.generate_id,
        guest_id: guest[:id],
        room_id: data[:room_id],
        check_in: data[:check_in],
        check_out: data[:check_out],
        status: "confirmed"
      }

      Store.bookings << booking
      booking
    end

    def update_booking(id, data)
      booking = Store.bookings.find { |b| b[:id] == id }
      raise "Booking not found: #{id}" unless booking

      booking[:check_in] = data[:check_in] if data[:check_in].present?
      booking[:check_out] = data[:check_out] if data[:check_out].present?

      booking
    end

    def cancel_booking(id)
      booking = Store.bookings.find { |b| b[:id] == id }
      raise "Booking not found: #{id}" unless booking

      booking[:status] = "cancelled"
      booking
    end

    def get_booking(id)
      booking = Store.bookings.find { |b| b[:id] == id }
      raise "Booking not found: #{id}" unless booking

      booking
    end
  end
end
