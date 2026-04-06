module Store
  @id_counter = 0

  @guests = []

  @rooms = [
    { id: "room-101", number: "101", floor: 1, type: "standard" },
    { id: "room-205", number: "205", floor: 2, type: "suite" },
    { id: "room-ph1", number: "PH1", floor: 10, type: "penthouse" }
  ]

  @bookings = []

  class << self
    attr_accessor :guests, :rooms, :bookings

    def generate_id
      @id_counter += 1
      "id-#{Time.now.to_i}-#{@id_counter}"
    end

    def find_room(id)
      @rooms.find { |r| r[:id] == id }
    end

    def find_guest(id)
      @guests.find { |g| g[:id] == id }
    end
  end
end
