# Requires here:
# require 'socket'


# Set the TCP server here:
# port = 10001
# server = TCPServer.new("localhost", port)


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
files_mtimes = {}
files_lines = {}


# Real stuff from here on:
loop do
	
	rss_body = ""
	
	Dir[FILES_PATTERN].each do |file_path|
		# DEBUG Print the file path:
		# puts file_path
		
		# First of all take note of the file's mtime:
		file_mtime = File.mtime(file_path)
		
		# Check if first execution:
		if (files_mtimes[file_path])
			
			if (files_mtimes[file_path] < file_mtime)
				
				# Initialize the RSS structures:
				
				
				
				# Initialize the variables used to track the changes:
				files_mtimes[file_path] = file_mtime
				count = 0
				
				File.open(file_path).each do |line|
					
					count += 1
					
					if (count >= files_lines[file_path])
						
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
				
				files_lines[file_path] = count
			end
		else
			# If it's first time executing then initialize variables
			
			files_mtimes[file_path] = file_mtime
		
			count = 0
			File.open(file_path).each {count += 1}
			files_lines[file_path] = count
			
			# DEBUG
			# puts "[Adding file '#{file_path}' to watched ones with lines #{count} and mtime '#{file_mtime}']"
		end
	
	end
	
	# DEBUG
	# puts "---------------------------------------------------------"
	# now = Time.now.to_s
	# puts "[Finished this round of indexing at #{now}]"
	# puts "---------------------------------------------------------"
	
	
	# Let's output the result of our efforts (rewrites the file every time we find changes!):
	File.open("rss.xml", 'w') do |file|
		file.write(RSS_PRE + rss_body + RSS_POST)
	end
	
	
	sleep EXECUTION_INTERVAL
	
end

