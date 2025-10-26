class DriveImporter

  # drive_files = DriveImporter.read_volume('anihd1')
  # DriveImporter.check(drive_files)
  # DriveImporter.write_movie(drive_files)

  def self.read_volume(volume = nil)
    if volume.nil?
      puts "volume missing"
      return nil
    end
    require 'find'

    # 1. Mount-Punkt definieren
    mount_path = "/mnt/moviedrive"

    # Überprüfen, ob das Verzeichnis existiert
    unless File.directory?(mount_path)
      puts "Fehler: Der Pfad '#{mount_path}' ist nicht vorhanden oder das Laufwerk nicht gemountet."
      exit
    end

    # Array zur Speicherung der Ergebnisse
    drive_files = []

    # Find.find durchsucht das Verzeichnis rekursiv
    Find.find(mount_path) do |path|
      # Nur reguläre Dateien verarbeiten (keine Ordner, Symlinks, etc.)
      if File.file?(path)
        begin
          # Dateiinformationen abrufen
          stats = File.stat(path)
          
          # Den Pfad relativ zum Mount-Punkt kürzen
          relative_path = path.sub("#{mount_path}/", '')
          
          # Die Daten speichern
          drive_files << {
            filename: relative_path,
            size_bytes: stats.size,
            # Optional: Größe in einer menschenlesbaren Form hinzufügen (hier in MB)
            size_mb: (stats.size.to_f / (1024 * 1024)).round(2) 
          }
          
        rescue Errno::EACCES
          # Fehlerbehandlung bei fehlenden Leserechten
          $stderr.puts "Warnung: Zugriff verweigert auf: #{path}"
        rescue Errno::ENOENT
          # Fehlerbehandlung, falls die Datei während des Scans verschwindet
          $stderr.puts "Warnung: Datei während des Scans verschwunden: #{path}"
        end
      end
    end

    drive_files.reject! do |file|
      # Wir prüfen, ob der :filename-Wert mit '$RECYCLE' beginnt.
      # Dies berücksichtigt auch Windows-Papierkorb-Ordnernamen wie "$RECYCLE.BIN"
      file[:filename].start_with?('$RECYCLE')
    end

    regex = %r{
      # 1. Movie Directory: Erfasst den optionalen Pfad
      (?:(?<movie_directory>.+/))?
      
      # 2. Movie Title: Erfasst alles bis zum (optionalen) Trennzeichen vor dem Jahr
      (?<movie>.*?)\s*
      
      # 3. Jahr (movie_year): Flexibel bei Leerzeichen \s*\(\s*\d{4}\s*\)\s*
      \s*\( *?(?<movie_year>\d{4}) *?\)\s*
      
      # 4. OPTIONALES ZWISCHENSTÜCK: Erlaubt Bindestriche, Punkte, Leerzeichen etc.
      (?:\s*[-.]*\s*)? # Erlaubt z.B. " - ", " -", oder einfach Leerzeichen
      
      # 5. Auflösung (resolution): MACHT DIESEN TEIL OPTIONAL
      #    Die Auflösung kann jetzt direkt auf das optionale Zwischenstück folgen.
      (?:\s*?(?<resolution>(?:[0-9]{3,4}[pi]?|dvd|bluray|hdrip|web[-_. ]?dl|webrip)))?
      
      # 6. Punkt und Dateityp (movietype)
      \.
      (?<movietype>[a-z0-9]{2,4})$
    }xi

    drive_files.map! do |movie|
#      UMLAUT_MAPPING.each do |malformed, correct_char|
 #       # Die Korrektur bleibt die gleiche
 #       movie[:filename].gsub!(malformed, correct_char) 
 #     end
      filename = movie[:filename]
      filename = filename.gsub(/[\s\u00A0\uFEFF]+/, ' ')

    #filename = "2014/Die Entdeckung der Unendlichkeit - (2014) 1080p.mkv"
      match_data = filename.match(regex)

      results = {}
      results[:volume] = volume
      if match_data
        # 1. Movie Directory (enthält alles vor dem letzten '/')
        #    Wir entfernen den nachgestellten Schrägstrich und nutzen .strip zur Bereinigung.
        #    Wenn die Gruppe 'movie_directory' nicht gefunden wird, ist der Wert nil.
        raw_dir = match_data[:movie_directory]
        results[:dir] = raw_dir ? raw_dir.chomp('/').strip : ''
        
        # 2. Movie Title (movie): Muss bereinigt werden, falls Leerzeichen vorhanden sind
        cleaned_movie = match_data[:movie].strip.sub(/(\s*[-.]*\s*)$/i, '')
        results[:title] = cleaned_movie
        
        # 3. Jahr (movie_year)
        results[:year] = match_data[:movie_year]
        

        # 4. Auflösung (resolution)
        results[:resolution] = match_data[:resolution] || 'N/A' # Setze N/A, falls nicht gefunden
        
        # 5. Dateityp (movietype)
        results[:type] = match_data[:movietype]

        results
      else
        results[:movie] = filename
      end
      results[:size] = movie[:size_mb]
      results
    end;
  end

  def self.check(drive_files)
    drive_files.each do |file|
      puts file[:movie] if file[:dir].nil?
    end;
    grouped_files = drive_files.group_by { |f| [f[:title]] }
    grouped_files.each do |key, files|
      if files.size > 1
       puts "✅ Duplikat: #{files.first}"
      end
    end;
    'done'
  end


  def self.write_movie(drive_files)

    drive_files.each do |data|
      # 1. Suchkriterien definieren: Title und Year müssen übereinstimmen
      search_criteria = { title: data[:title], year: data[:year] }
      
      # 2. Bestehenden Eintrag suchen ODER ein neues Objekt initialisieren
      #    find_or_initialize_by ändert die Datenbank NICHT.
      movie = Movie.find_or_initialize_by(search_criteria)
      
      # 3. Das Movie-Objekt mit den neuen/aktualisierten Werten füllen
      #    Wir überschreiben nur die Felder, die aktualisiert werden sollen.
      movie.volume    = data[:volume]
      movie.dir       = data[:dir]
      movie.resolution= data[:resolution]
      movie.type      = data[:type]
      movie.size      = data[:size]
      # created_at/updated_at werden automatisch von ActiveRecord verwaltet
      
      # 4. Speichern und prüfen
      if movie.save
        if movie.new_record? # Wenn das Objekt vor dem Speichern neu war
          puts "🎬 Neu eingefügt: #{movie.title} (#{movie.year})"
        else
          puts "🔄 Aktualisiert: #{movie.title} (#{movie.year})"
        end
      else
        $stderr.puts "❌ Fehler beim Speichern von #{data[:title]}: #{movie.errors.full_messages.join(', ')}"
      end
    end
    'done'

  end


end
