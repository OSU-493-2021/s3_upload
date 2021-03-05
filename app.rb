#Reference: https://docs.aws.amazon.com/sdk-for-ruby/v3/developer-guide/hello.html
#Reference: https://docs.aws.amazon.com/sdk-for-ruby/v3/developer-guide/s3-example-upload-bucket-item.html
#Reference: https://docs.aws.amazon.com/sdk-for-ruby/v2/api/Aws/S3/Client.html
#Reference: https://docs.aws.amazon.com/code-samples/latest/catalog/ruby-s3-s3-ruby-example-list-bucket-items.rb.html
#Reference: https://docs.aws.amazon.com/sdk-for-ruby/v3/developer-guide/aws-sdk-ruby-dg.pdf

require 'aws-sdk'
require 'aws-sdk-s3'
require 'pathname'
require 'aws-sdk-dynamodb'

#Command Line argument work
NO_SUCH_BUCKET = "The bucket '%s' does not exist!"

USAGE = <<DOC

Usage: ruby app.rb [bucket_name] [operation] [file_name]

Where:

bucket_name (required) is the name of the bucket

operation   is the operation to perform on the bucket:
            upload  - uploads a file to the bucket
            upload_album - uploads an album to the s3bucket
            upload_artist - uploads an artist to the s3bucket
            rename       - renames an existing file in the s3bucket
            list    - lists bucket objects in a particular s3 bucket

file_name   is the name of the file to upload, which can be a File path or a filename
            required when operation is 'upload'

Buckets are listed below: 

DOC

#assume the role
role_credentials = Aws::AssumeRoleCredentials.new(
  client: Aws::STS::Client.new,
  role_arn: "arn:aws:iam::589772831734:role/meusick-api-node-dev-us-east-1-lambdaRole",
  role_session_name: "s3-upload-session"
)

#Get the Amazon client role credentials
s3_client = Aws::S3::Client.new(credentials: role_credentials)

#Sets the name of the bucket on which the operations are performed
bucket_name = nil

if ARGV.length > 0
  bucket_name = ARGV[0]
else
  puts USAGE
  pp s3_client.list_buckets
  exit 1
end

#The operation to be performed on the bucket
operation = ARGV[1] if (ARGV.length > 1)

#The file name to use alongside 'upload'
file = nil
file = ARGV[2] if (ARGV.length > 2)

#The new name to use alongside 'rename'
new_name = nil
new_name = ARGV[3] if (ARGV.length > 3)

#Different the operation name matches ARGV[1]
case operation

#To upload a file to the s3 bucket
when 'upload'
  if file == nil
    puts "You must enter a file name to upload to S3!"
    exit
  else
    file_name= File.basename file
    s3_client.put_object( bucket: bucket_name, key: file_name)
    puts "SUCCESS: File '#{file_name}' successfuly uploaded to bucket '#{bucket_name}'."
  end

#To upload a folder/alum/directory
when 'upload_artist'
  if file == nil
    puts "You must enter a folder path to upload to S3!"
    exit
  else
    folder_name = File.basename(file, ".*")
    path_names = Pathname(folder_name).each_child {|inner_file| 
    if inner_file.directory? 
      Dir.each_child(inner_file) do |song_names|
        s3_client.put_object( bucket: bucket_name, key: "#{inner_file}/#{song_names}")
      end      
    end
}
#Dir.each_child('test') do |e|
#  Dir.each_child(dir + '/test/' + e) do |f|
#   pp f
#  end
#end
    puts "SUCCESS: Artist'#{folder_name}' successfuly uploaded to bucket '#{bucket_name}'."
  end

#To upload an album
when 'upload_album'
  if file == nil
    puts "You must enter a folder path to upload to S3!"
    exit
  else
    folder_name = File.basename(file, ".*")
    Dir.each_child(file) do |filename|
      next if filename == '.' or filename == '..'
      s3_client.put_object( bucket: bucket_name, key: "#{folder_name}/#{filename}")
    end
    puts "SUCCESS: Album'#{folder_name}' successfuly uploaded to bucket '#{bucket_name}'."
  end

#To list the objects inside of a bucket
when 'list'
  if bucket_name == nil
    puts "You must enter a Bucket-name!"
    exit
  else
    puts "Contents of '%s':" % bucket_name
    objects = s3_client.list_objects_v2(
    bucket: bucket_name, max_keys: 10).contents
      if objects.count.zero?
        puts "No objects in bucket '#{bucket_name}'."
        return
      else
        objects.each do |object|
          puts object.key
        end
      end
    end

#To rename an existing object inside of a bucket
when 'rename'
  if file == nil && new_name == nil
    puts "You must enter a file name and the new name of that file to rename!"
    exit
  else
    file_name=File.basename file 
    s3_client.copy_object(bucket: bucket_name,
                  copy_source: "#{bucket_name}/#{file_name}",
                  key: new_name)

    s3_client.delete_object(bucket: bucket_name,
                    key: file_name)
    puts "SUCCESS: File '#{file_name}' successfuly changed name to '#{new_name}'."
  end

when 'put'
  def add_item_to_table(dynamodb_client, table_item)
    dynamodb_client.put_item(table_item)
    puts "Added song '#{table_item[:item][:genre]} " \
      "(#{table_item[:item][:artist]})'."
  rescue StandardError => e
    puts "Error adding song '#{table_item[:item][:genre]} " \
      "(#{table_item[:item][:artist]})': #{e.message}"
  end

  def run_me()
    region = 'us-east-1'
    table_name = 'music'
    genre = 'Music Genre'
    artist = "Artist Name"

    # To use the downloadable version of Amazon DynamoDB,
    # uncomment the endpoint statement.
    Aws.config.update(
      # endpoint: 'http://localhost:8000',
      region: region
    )

    dynamodb_client = Aws::DynamoDB::Client.new

    item = {
      artist: artist,
      genre: genre,
      info: {
        albums: 'Some album information.',
        songs: 'Some song information.'
      }
    }

    table_item = {
      table_name: table_name,
      item: item
    }

    puts "Adding song '#{item[:genre]} (#{item[:artist]})' " \
      "to table '#{table_name}'..."
    add_item_to_table(dynamodb_client, table_item)
  end

  run_me()

else
  puts "Unknown operation: '%s'!" % operation
  puts USAGE
end