class MovieDriveImporter

  # sudo mount -t drvfs I: /mnt/moviedrive
  # drive_files = MovieDriveImporter.read_volume('Collections 1')
  # MovieDriveImporter.check(drive_files)
  # MovieDriveImporter.write_movie(drive_files)

  def self.read_volume(volume = nil)
    if volume.nil?
      puts "volume missing"
      return nil
    end
    require 'find'

    mount_path = "/mnt/moviedrive"

    unless File.directory?(mount_path)
      puts "Fehler: Der Pfad '#{mount_path}' ist nicht vorhanden oder das Laufwerk nicht gemountet."
      exit
    end

    drive_files = []

    Find.find(mount_path) do |path|
      if File.file?(path)
        begin
          stats = File.stat(path)
          relative_path = path.sub("#{mount_path}/", '')

          drive_files << {
            filename: relative_path,
            size_bytes: stats.size,
            size_mb: (stats.size.to_f / (1024 * 1024)).round(2) 
          }
          
        rescue Errno::EACCES
          $stderr.puts "Warnung: Zugriff verweigert auf: #{path}"
        rescue Errno::ENOENT
          $stderr.puts "Warnung: Datei während des Scans verschwunden: #{path}"
        end
      end
    end

    drive_files.reject! do |file|
      file[:filename].start_with?('$RECYCLE') || file[:filename].end_with?('.jpg')
    end

    regex = %r{
      # 1. Movie Directory: 
      (?:(?<movie_directory>.+/))?
      
      # 2. Movie Title: 
      (?<movie>.*?)\s*
      
      # 3. Jahr (movie_year): Flexibel bei Leerzeichen \s*\(\s*\d{4}\s*\)\s*
      (?:\s*\( *?(?<movie_year>\d{4}) *?\)\s*)?
      
      # 4. OPTIONALES ZWISCHENSTÜCK: Erlaubt Bindestriche, Punkte, Leerzeichen etc.
      (?:\s*[-.]*\s*)? # Erlaubt z.B. " - ", " -", oder einfach Leerzeichen
      
      # 5. Auflösung (resolution):
      #    Die Auflösung kann jetzt direkt auf das optionale Zwischenstück folgen.
      (?:\s*?(?<resolution>(?:[0-9]{3,4}[pi]?|dvd|bluray|hdrip|web[-_. ]?dl|webrip)))?
      
      # 6. Punkt und Dateityp (movietype)
      \.
      (?<movietype>[a-z0-9]{2,4})$
    }xi

    drive_files.map! do |movie|

      filename = movie[:filename]
      filename = filename.gsub(/[\s\u00A0\uFEFF]+/, ' ')

      match_data = filename.match(regex)

      results = {}
      results[:volume] = volume
      if match_data
        # 1. Movie Directory 
        raw_dir = match_data[:movie_directory]
        results[:dir] = raw_dir ? raw_dir.chomp('/').strip : ''
        
        # 2. Movie Title 
        cleaned_movie = match_data[:movie].strip.sub(/(\s*[-.]*\s*)$/i, '')
        results[:title] = cleaned_movie
        
        # 3. Jahr (movie_year)
        results[:year] = match_data[:movie_year] || 'N/A'
        
        if results[:year] == 'N/A'
          # "Alfred Hitchcock - 1935 - Die 39 Stufen" extrakt year in title
          if results[:title] =~ / - (\d{4}) - /
            results[:year] = $1 
            results[:title].sub!(/ - \d{4} - /, ' - ')
          end
        end

        # 4. Auflösung (resolution)
        results[:resolution] = match_data[:resolution] || 'N/A' 
        
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
    grouped_files = drive_files.group_by { |f| [f[:title],f[:year]] }
    grouped_files.each do |key, files|
      if files.size > 1
       puts "✅ Duplikat: #{files.first}"
      end
    end;
    'done'
  end


  def self.write_movie(drive_files)

    drive_files.each do |data|

      search_criteria = { title: data[:title], year: data[:year] }
      movie = Movie.find_or_initialize_by(search_criteria)
      is_new_record = movie.new_record?

      movie.volume    = data[:volume]
      movie.dir       = data[:dir]
      movie.resolution= data[:resolution]
      movie.type      = data[:type]
      movie.size      = data[:size]

      if movie.save
        if is_new_record
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
