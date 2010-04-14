# Requires here:
require 'socket'
require 'date'
require 'rss'


# Set the TCP server here:
port = 10001
server = TCPServer.new("localhost", port)


# XML stuff here:
RSS_PRE = "<?xml version=\"1.0\" encoding=\"UTF-8\" ?>
<rss version=\"2.0\">
<channel>
  <title>logsexposd</title>
  <link>feelingblack.blogspot.com</link>
  <description>Logs Exposition using a Daemon</description>
  <language>en-us</language>"

RSS_POST = "</channel></rss>"


# Configuration constants here:
FILES_PATTERN = "/var/log/*.log"
EXECUTION_INTERVAL = 6 	# interval is in seconds
RSS_FILE_NAME = "rss.xml"


# Initialization here:
rss = ""
files_mtimes = {}
files_lines = {}
files_firstline_hashes = {}

Dir[FILES_PATTERN].each do |file_path|
	file_mtime = File.mtime(file_path)
	files_mtimes[file_path] = file_mtime

	count = 0
	File.open(file_path).each do |line|
		
		if (count == 0)
			files_firstline_hashes[file_path] = line.hash
		end
		
		count += 1
	end
	
	files_lines[file_path] = count

	# DEBUG
	puts "[Adding file '#{file_path}' to watched ones with lines #{count} and mtime '#{file_mtime}']"
end


# First of all we start the thread responsible for indexing the log files
# and writing the results as RSS to a file:
Thread.start(rss) do |rss|
	# Execute indefinitely
	loop do
		rss_body = ""
		
		Dir[FILES_PATTERN].each do |file_path|
			# First of all take note of the file's mtime:
			file_mtime = File.mtime(file_path)
			
			# Then initialize some auxiliary variables:
			has_rotated = false
		
			# Check whether the file has changed since last run:
			if (files_mtimes[file_path] < file_mtime)
				# Initialize the variables used to track the changes:
				# 1. the mtime-s are used to track the last time the file has been modified
				# 2. 'count' counts the number of lines of the file
				files_mtimes[file_path] = file_mtime
				count = 0

				# DEBUG
				puts ("Found that mtime has changes for '#{file_path}'")
				
				File.open(file_path).each do |line|
				
					# Check whether the log has been rotated by analysing its first line:
					if (count == 0)
						if (files_firstline_hashes[file_path] != line.hash)
							# DEBUG
							puts ("Found that '#{file_path}' has rotated")
							
							has_rotated = true
						end
					end
				
				
					count += 1
				
				
					# If log has rotated log every line of the file,
					# otherwise get only the new lines
					if (has_rotated or count >= files_lines[file_path])
						rss_item = "<item>
									<title>#{file_path} at #{file_mtime} [line #{count}]</title>
									<link>#none</link>
									<description>"
					
						rss_item += RSS::Utils.html_escape(line)
					
						rss_item += "</description></item>"
					
						# This way we ensure the last lines are showed first
						rss_body = rss_item + rss_body
					end
				end
			
				# Save the new number of lines of the file:
				files_lines[file_path] = count
			end
	
		end
	
	
		# Now incrementally increase the RSS being output with the newly added elements:
		rss = rss_body + rss
		

		# DEBUG
		puts ("Parsed the logs and produced the following: \n#{rss}")
		
		
		File.open(RSS_FILE_NAME, "w") do |file|
			
			# DEBUG
			puts ("Writing to file #{RSS_FILE_NAME}")
			
			file.write(RSS_PRE + rss + RSS_POST)
		end
		
		
		# Now sleep for EXECUTION_INTERVAL
		sleep EXECUTION_INTERVAL
	end
end


# These threads accept connections and serve the RSS file we created:
loop do
	Thread.start(server.accept) do |session|
		# DEBUG Let's know we are up and alive:
		time = Time.now.to_s
		puts ("Serving request at " + time)
	
		if (File.exists? RSS_FILE_NAME)
			session.print(IO.read(RSS_FILE_NAME))
		end
	
		session.close
	end
end

