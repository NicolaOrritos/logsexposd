# Requires here:
require 'socket'
require 'date'


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
EXECUTION_INTERVAL = 10 	# interval is in seconds


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


# Real stuff from here on:
while (session = server.accept) do
	
	# DEBUG Let them know we are up and alive:
	time = Time.now.to_s
	puts ("Serving request at " + time)
	
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
			
			File.open(file_path).each do |line|
				
				# Check whether the log has been rotated by analysing its first line:
				if (count == 0)
					if (files_firstline_hashes[file_path] == line.hash)
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
					
					rss_item += line
					
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
	
	
	# Let's output the result of our efforts:
	response_body = RSS_PRE + rss + RSS_POST
	
	
	session.print(response_body)
	
	session.close
	
end

