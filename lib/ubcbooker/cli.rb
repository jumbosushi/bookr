module Ubcbooker
  class CLI
    attr_accessor :options

    def initialize
      @config = Ubcbooker::Config.new
      @options = nil
    end

    def parse_options

      # This will hold the options we parse
      options = {
        name: nil,
        date: nil,
        time: nil,
        department: nil,
      }

      # TODO: Change department to building
      OptionParser.new do |parser|
        parser.on("-b", "--building BUILDING", String, "Specify which department to book rooms from") do |v|
          if CLI::Validator.is_valid_department(v)
            options[:department] = v
          else
            raise Ubcbooker::Error::UnsupportedDepartment.new(v)
          end
        end

        parser.on("-d", "--date DATE", String, "Specify date to book rooms for (MM/DD)") do |v|
          if CLI::Validator.is_valid_date(v)
            options[:date] = v
          else
            raise Ubcbooker::Error::UnsupportedDate.new(v)
          end
        end

        parser.on("-h", "--help", "Show this help message") do
          puts parser
          puts "\nex. Book a room in CS from 11am to 1pm on March 5th with the name 'Study Group'\n" <<
               "    $ ubcbooker -b cs -n 'Study Group' -d 03/05 -t 11:00-13:00"
          exit(0)
        end

        parser.on("-l", "--list", "List supported departments") do |v|
          @config.print_supported_departments
          exit(0)
        end

        parser.on("-n", "--name NAME", String, "Name of the booking") do |v|
          if CLI::Validator.is_valid_name(v)
            options[:name] = v
          else
            raise Ubcbooker::Error::ProfaneName.new(v)
          end
        end
        parser.on("-t", "--time TIME", String,
                  "Specify time to book rooms for (HH:MM-HH:MM)") do |v|
          if CLI::Validator.is_valid_time(v)
            options[:time] = v
          else
            raise Ubcbooker::Error::UnsupportedTime.new(v)
          end
        end

        parser.on("-u", "--update", "Update username and password") do |v|
          @config.ask
          exit(0)
        end

        parser.on("-v", "--version", "Show version") do |v|
          puts Ubcbooker::VERSION
          exit(0)
        end
      end.parse!

      spinner = get_spinner("Verifying inputs")
      spinner.success("Done!") # Stop animation

      if CLI::Validator.is_required_missing(options)
        raise Ubcbooker::Error::MissingRequired
      end

      return options
    end

    def get_options
      option_errors = [
        Ubcbooker::Error::UnsupportedDepartment,
        Ubcbooker::Error::UnsupportedTime,
        Ubcbooker::Error::UnsupportedDate,
        Ubcbooker::Error::ProfaneName,
        Ubcbooker::Error::MissingRequired,
      ]

      begin
        return parse_options
      rescue *option_errors => e
        puts e.message
        exit(1)
      end
    end

    def get_department_scraper(department)
      case department
      when "cs"
        return Ubcbooker::Scraper::Cs
      when "sauder_ugrad"
        return Ubcbooker::Scraper::SauderUgrad
      else
        raise Ubcbooker::Error::UnsupportedDepartment.new(department)
      end
    end

    def get_scraper(department, username, password)
      scraper_client = get_department_scraper(department)
      return scraper_client.new(username, password)
    end

    def get_spinner(text)
      spinner = ::TTY::Spinner.new("[:spinner] #{text} ... ", format: :dots)
      spinner.auto_spin # Automatic animation with default interval
      return spinner
    end

    def start
      book_errors = [
        Ubcbooker::Error::NoAvailableRoom,
        Ubcbooker::Error::BookingFailed,
      ]

      @options = get_options
      if !@config.defined? || @config.is_windows?
        @config.ask
      end

      @client = get_scraper(@options[:department],
                            @config.get_username,
                            @config.get_password)
      begin
        room_id = @client.book(@options)
        puts "Success! #{room_id} is booked".green
      rescue *book_errors => e
        puts e.message
        exit(1)
      end
    end
  end
end
