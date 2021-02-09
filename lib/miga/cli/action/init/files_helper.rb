# frozen_string_literal: true

##
# Helper module with files configuration functions for MiGA::Cli::Action::Init
module MiGA::Cli::Action::Init::FilesHelper
  def open_rc_file
    rc_path = File.expand_path('.miga_rc', ENV['HOME'])
    if File.exist? rc_path
      if cli.ask_user(
        'I found a previous configuration. Do you want to continue?',
        'yes', %w(yes no)
      ) == 'no'
        cli.puts 'OK, see you soon!'
        exit(0)
      end
    end
    rc_fh = File.open(rc_path, 'w')
    rc_fh.puts <<~BASH
      #!/bin/bash
      # `miga init` made this on #{Time.now}

    BASH
    rc_fh
  end

  def close_rc_file(rc_fh)
    rc_fh.puts <<~FOOT

      MIGA_CONFIG_VERSION='#{MiGA::MiGA.VERSION}'
      MIGA_CONFIG_LONGVERSION='#{MiGA::MiGA.LONG_VERSION}'
      MIGA_CONFIG_DATE='#{Time.now}'

    FOOT
    rc_fh.close
  end

  def check_configuration_script(rc_fh)
    unless File.exist? cli[:config]
      cli[:config] = cli.ask_user(
        'Is there a script I need to load at startup?',
        cli[:config]
      )
    end
    if File.exist? cli[:config]
      cli[:config] = File.expand_path(cli[:config])
      cli.puts "Found bash configuration script: #{cli[:config]}"
      rc_fh.puts "MIGA_STARTUP='#{cli[:config]}'"
      rc_fh.puts '. "$MIGA_STARTUP"'
    else
      cli[:config] = '/dev/null'
    end
    cli.puts ''
  end

  def check_additional_files(paths)
    if cli[:mytaxa]
      check_mytaxa_scores(paths)
      check_mytaxa_database(paths)
    end
    check_rdp_classifier if cli[:rdp]
    check_phyla_lite
  end

  def check_mytaxa_scores(paths)
    cli.print 'Looking for MyTaxa scores... '
    mt = File.dirname(paths['MyTaxa'])
    unless Dir.exist?(File.join(mt, 'db'))
      cli.puts "no\nExecute 'python2 #{mt}/utils/download_db.py'"
      raise 'Incomplete MyTaxa installation'
    end
    cli.puts 'yes'
  end

  def check_mytaxa_database(paths)
    cli.print 'Looking for MyTaxa DB... '
    mt = File.dirname(paths['MyTaxa'])
    dmnd_db = 'AllGenomes.faa.dmnd'
    miga_db = File.join(ENV['MIGA_HOME'], '.miga_db')
    home_db = File.join(miga_db, dmnd_db)
    mt_db = File.join(mt, 'AllGenomes.faa.dmnd')
    if File.exist?(home_db)
      cli.puts 'yes'
    elsif File.exist?(mt_db)
      cli.puts 'yes, sym-linking'
      File.symlink(mt_db, home_db)
    else
      cli.puts 'no, downloading'
      MiGA::MiGA.download_file_ftp(:miga_dist, dmnd_db, home_db) do |n, size|
        cli.advance("#{dmnd_db}:", n, size)
      end
      cli.puts
    end
  end

  def check_rdp_classifier
    cli.print 'Looking for RDP classifier... '
    miga_db = File.join(ENV['MIGA_HOME'], '.miga_db')
    file = 'classifier.jar'
    path = File.join(miga_db, file)
    if File.size?(path)
      cli.puts 'yes'
    else
      cli.puts 'no, downloading'
      arch = 'classifier.tar.gz'
      MiGA::MiGA.download_file_ftp(
        :miga_dist, arch, File.join(miga_db, arch)
      ) { |n, size| cli.advance("#{arch}:", n, size) }
      `cd '#{miga_db}' && tar zxf '#{arch}' && rm '#{arch}'`
      cli.puts
    end
  end

  def check_phyla_lite
    cli.puts 'Looking for Phyla Lite... '
    cmd = ['get_db', '-n', 'Phyla_Lite', '--no-overwrite']
    MiGA::Cli.new(cmd).launch(true)
  end
end
