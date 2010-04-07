# Requires here:
require 'socket'


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

Dir[FILES_PATTERN].each do |file_path|
	file_mtime = File.mtime(file_path)
	files_mtimes[file_path] = file_mtime

	count = 0
	File.open(file_path).each {count += 1}
	files_lines[file_path] = count

	# DEBUG
	puts "[Adding file '#{file_path}' to watched ones with lines #{count} and mtime '#{file_mtime}']"
end


# Real stuff from here on:
while (session = server.accept) do
	
	# DEBUG Let them know we are up and alive:
	puts "Serving request"
	
	rss_body = ""
	rss_buffer_body = ""
	
	Dir[FILES_PATTERN].each do |file_path|
		# First of all take note of the file's mtime:
		file_mtime = File.mtime(file_path)
		
		if (files_mtimes[file_path] < file_mtime)
			# Initialize the variables used to track the changes:
			files_mtimes[file_path] = file_mtime
			count = 0
			
			File.open(file_path).each do |line|
				
				count += 1
				
				rss_item = "<item>
							<title>#{file_path} at #{file_mtime} [line #{count}]</title>
							<link>#none</link>
							<description>"
				
				rss_item += line
				
				rss_item += "</description></item>"
				
				if (count >= files_lines[file_path])
					# DEBUG
					puts ("[The following line in output as *normal* RSS body:]\n#{line}")
					
					# This way we ensure the last lines are showed first
					rss_body = rss_item + rss_body
				else
					# DEBUG
					puts ("[The following line in output as *buffered* RSS body:]\n#{line}")
					
					# This buffered body will only be used if the log has been rotated:
					rss_buffer_body = rss_item + rss_buffer_body
				end
			end
			
			
			# Corner-case: logs could be rotated,
			# hence the new ".log" could have fewer lines
			# than the number saved in files_lines[]
			if (count < files_lines[file_path])
				rss_body += rss_buffer_body
			end
			
			
			files_lines[file_path] = count
		end
	
	end
	
	
	# Now incrementally increase the RSS being output with the newly added elements:
	rss = rss_body + rss
	
	
	# Let's output the result of our efforts (rewrites the file every time we find changes!):
	response_body = RSS_PRE + rss + RSS_POST
	
	
	session.print(response_body)
	
	session.close
	
end

