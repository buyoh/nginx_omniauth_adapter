replaced_server_name = gets.chomp
original_server_name = 'ngx-auth-test.lo.nkmiusercontent.com'

['nginx-site.conf', 'nginx.conf'].each do |filepath|
  File.open(filepath) do |io_src|
    File.open("var/#{filepath}", 'w') do |io_dst|
      while line = io_src.gets
        io_dst.print line.gsub(original_server_name, replaced_server_name)
      end
    end
  end
end
