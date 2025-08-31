# frozen_string_literal: true

module NorwegianCompliance
  # Norwegian localization service with nb_NO locale and NOK currency
  class LocalizationService
    include ActionView::Helpers::NumberHelper

    NORWEGIAN_LOCALES = %w[nb_NO nn_NO].freeze
    SUPPORTED_CITIES = %w[bergen oslo trondheim stavanger tromsø kristiansand drammen fredrikstad].freeze
    CURRENCY_CODE = "NOK"

    attr_reader :locale, :city, :timezone

    def initialize(locale: :nb, city: nil, timezone: "Europe/Oslo")
      @locale = normalize_locale(locale)
      @city = city&.downcase
      @timezone = timezone
    end

    # Format currency amounts in Norwegian Kroner
    def format_currency(amount, precision: 2)
      number_to_currency(
        amount,
        unit: "kr ",
        separator: ",",
        delimiter: " ",
        precision: precision,
        format: "%u%n"
      )
    end

    # Format numbers with Norwegian conventions
    def format_number(number, precision: 0)
      number_with_precision(
        number,
        separator: ",",
        delimiter: " ",
        precision: precision
      )
    end

    # Format dates in Norwegian style
    def format_date(date, format: :default)
      return nil unless date

      date = date.to_date if date.respond_to?(:to_date)
      
      case format
      when :short
        date.strftime("%d.%m.%Y")
      when :long
        I18n.l(date, format: :long, locale: @locale)
      when :month_year
        date.strftime("%B %Y").capitalize
      else
        date.strftime("%d. %B %Y")
      end
    end

    # Format time with Norwegian timezone
    def format_time(time, format: :default)
      return nil unless time

      time_in_oslo = time.in_time_zone(@timezone)
      
      case format
      when :short
        time_in_oslo.strftime("%H:%M")
      when :long
        time_in_oslo.strftime("%d.%m.%Y kl. %H:%M")
      else
        time_in_oslo.strftime("%H:%M")
      end
    end

    # Get localized content for healthcare services
    def healthcare_service_name(service_key)
      I18n.t("healthcare.services.#{service_key}", locale: @locale, default: service_key.humanize)
    end

    # Get city-specific information
    def city_information
      return default_city_info unless @city && SUPPORTED_CITIES.include?(@city)

      {
        name: city_display_name,
        timezone: city_timezone,
        emergency_number: "113",
        health_authority: health_authority_for_city,
        major_hospitals: hospitals_for_city,
        public_transport: public_transport_info,
        postal_codes: postal_codes_for_city
      }
    end

    # Get Norwegian health system information
    def health_system_info
      {
        emergency_services: {
          medical_emergency: "113",
          fire: "110",
          police: "112",
          poison_center: "22 59 13 00"
        },
        patient_rights: {
          free_treatment: true,
          maximum_annual_cost: format_currency(3275), # 2024 ceiling
          prescription_ceiling: format_currency(2300),
          dental_support_age_limit: 18
        },
        health_regions: norwegian_health_regions,
        referral_system: referral_system_info
      }
    end

    # Validate Norwegian national ID (fødselsnummer)
    def validate_national_id(national_id)
      return false unless national_id.is_a?(String)
      
      # Remove spaces and validate format
      cleaned = national_id.gsub(/\s/, "")
      return false unless cleaned.match?(/^\d{11}$/)

      # Validate birth date
      day = cleaned[0..1].to_i
      month = cleaned[2..3].to_i
      year = "19#{cleaned[4..5]}".to_i
      
      # Handle century calculation for D-numbers
      if cleaned[0].to_i >= 4
        day -= 40
        year += 100 if year < 1940
      end

      return false unless valid_date?(day, month, year)

      # Validate control digits
      validate_control_digits(cleaned)
    end

    # Get Norwegian legal holidays
    def norwegian_holidays(year = Date.current.year)
      holidays = {
        "Nyttårsdag" => Date.new(year, 1, 1),
        "Skjærtorsdag" => easter_date(year) - 3.days,
        "Langfredag" => easter_date(year) - 2.days,
        "1. påskedag" => easter_date(year),
        "2. påskedag" => easter_date(year) + 1.day,
        "Arbeidernes dag" => Date.new(year, 5, 1),
        "Grunnlovsdag" => Date.new(year, 5, 17),
        "Kristi himmelfartsdag" => easter_date(year) + 39.days,
        "1. pinsedag" => easter_date(year) + 49.days,
        "2. pinsedag" => easter_date(year) + 50.days,
        "Julaften" => Date.new(year, 12, 24),
        "1. juledag" => Date.new(year, 12, 25),
        "2. juledag" => Date.new(year, 12, 26)
      }

      holidays.transform_values { |date| format_date(date, :long) }
    end

    # Business hours considering Norwegian culture
    def business_hours
      {
        weekdays: "08:00-16:00",
        saturday: "10:00-15:00",
        sunday: "Stengt",
        emergency_always_available: true,
        lunch_break: "12:00-13:00"
      }
    end

    private

    def normalize_locale(locale)
      case locale.to_s.downcase
      when "nb", "nb_no", "norsk", "bokmål"
        :nb
      when "nn", "nn_no", "nynorsk"
        :nn
      when "en", "en_us", "english"
        :en
      else
        :nb
      end
    end

    def city_display_name
      case @city
      when "bergen"
        "Bergen"
      when "oslo"
        "Oslo"
      when "trondheim"
        "Trondheim"
      when "stavanger"
        "Stavanger"
      when "tromsø"
        "Tromsø"
      when "kristiansand"
        "Kristiansand"
      when "drammen"
        "Drammen"
      when "fredrikstad"
        "Fredrikstad"
      else
        @city.capitalize
      end
    end

    def city_timezone
      # Most of Norway is in CET/CEST
      "Europe/Oslo"
    end

    def health_authority_for_city
      case @city
      when "bergen", "stavanger"
        "Helse Vest"
      when "oslo", "drammen", "fredrikstad"
        "Helse Sør-Øst"
      when "trondheim"
        "Helse Midt-Norge"
      when "tromsø"
        "Helse Nord"
      when "kristiansand"
        "Helse Sør-Øst"
      else
        "Se helsenorge.no"
      end
    end

    def hospitals_for_city
      case @city
      when "bergen"
        ["Haukeland universitetssjukehus", "Haraldsplass Diakonale Sykehus"]
      when "oslo"
        ["Oslo universitetssykehus", "Akershus universitetssykehus", "Lovisenberg Diakonale Sykehus"]
      when "trondheim"
        ["St. Olavs hospital"]
      when "stavanger"
        ["Stavanger universitetssjukehus"]
      when "tromsø"
        ["Universitetssykehuset Nord-Norge"]
      else
        ["Se 1177.no for nærmeste sykehus"]
      end
    end

    def public_transport_info
      case @city
      when "bergen"
        { provider: "Skyss", website: "skyss.no" }
      when "oslo"
        { provider: "Ruter", website: "ruter.no" }
      when "trondheim"
        { provider: "AtB", website: "atb.no" }
      when "stavanger"
        { provider: "Kolumbus", website: "kolumbus.no" }
      when "tromsø"
        { provider: "Troms fylkestrafikk", website: "tromsreise.no" }
      else
        { provider: "Se kommunens hjemmeside", website: nil }
      end
    end

    def postal_codes_for_city
      case @city
      when "bergen"
        "5000-5099"
      when "oslo"
        "0000-1299"
      when "trondheim"
        "7000-7099"
      when "stavanger"
        "4000-4099"
      when "tromsø"
        "9000-9099"
      when "kristiansand"
        "4600-4699"
      when "drammen"
        "3000-3099"
      when "fredrikstad"
        "1600-1699"
      else
        "Se posten.no"
      end
    end

    def norwegian_health_regions
      [
        {
          name: "Helse Nord",
          counties: ["Nordland", "Troms og Finnmark"],
          website: "helse-nord.no"
        },
        {
          name: "Helse Midt-Norge",
          counties: ["Trøndelag", "Møre og Romsdal"],
          website: "helse-midt.no"
        },
        {
          name: "Helse Vest",
          counties: ["Rogaland", "Vestland"],
          website: "helse-vest.no"
        },
        {
          name: "Helse Sør-Øst",
          counties: ["Oslo", "Viken", "Innlandet", "Vestfold og Telemark", "Agder"],
          website: "helse-sorost.no"
        }
      ]
    end

    def referral_system_info
      {
        primary_care: "Fastlege (GP)",
        referral_required: true,
        emergency_exceptions: ["Akutt sykdom", "Ulykke", "Psykisk helsehjelp"],
        direct_access: ["Øyeblikkelig hjelp", "Jordmortjeneste", "Fysioterapi"]
      }
    end

    def default_city_info
      {
        name: "Norge",
        timezone: @timezone,
        emergency_number: "113",
        health_authority: "Se helsenorge.no",
        major_hospitals: ["Se 1177.no"],
        public_transport: { provider: "Varierer per kommune", website: nil },
        postal_codes: "0000-9999"
      }
    end

    def valid_date?(day, month, year)
      return false if month < 1 || month > 12
      return false if day < 1

      days_in_month = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
      
      # Adjust for leap year
      if month == 2 && leap_year?(year)
        days_in_month[1] = 29
      end

      day <= days_in_month[month - 1]
    end

    def leap_year?(year)
      (year % 4 == 0 && year % 100 != 0) || (year % 400 == 0)
    end

    def validate_control_digits(national_id)
      # Norwegian national ID control digit validation
      weights1 = [3, 7, 6, 1, 8, 9, 4, 5, 2]
      weights2 = [5, 4, 3, 2, 7, 6, 5, 4, 3, 2]

      sum1 = weights1.zip(national_id[0..8].chars).sum { |w, d| w * d.to_i }
      control1 = (11 - (sum1 % 11)) % 11
      return false if control1 >= 10 || control1 != national_id[9].to_i

      sum2 = weights2.zip(national_id[0..9].chars).sum { |w, d| w * d.to_i }
      control2 = (11 - (sum2 % 11)) % 11
      return false if control2 >= 10 || control2 != national_id[10].to_i

      true
    end

    def easter_date(year)
      # Calculate Easter Sunday using the algorithm
      a = year % 19
      b = year / 100
      c = year % 100
      d = b / 4
      e = b % 4
      f = (b + 8) / 25
      g = (b - f + 1) / 3
      h = (19 * a + b - d - g + 15) % 30
      i = c / 4
      k = c % 4
      l = (32 + 2 * e + 2 * i - h - k) % 7
      m = (a + 11 * h + 22 * l) / 451
      n = (h + l - 7 * m + 114) / 31
      p = (h + l - 7 * m + 114) % 31

      Date.new(year, n, p + 1)
    end
  end
end