require "tmpdir"

CONTENT_TYPE_FOR_EXT = {
  ".sig" => "application/pgp-signature",
  ".db" => "application/zstd",
  ".files" => "application/zstd",
  ".zst" => "application/zstd",
  ".txt" => "text/plain",
}

def repo_release
  require "octokit"

  tag = ENV['DEPLOY_TAG']
  repo = ENV['DEPLOY_REPO_NAME']
  token = ENV['DEPLOY_TOKEN']
  client = Octokit::Client.new(access_token: token)
  rel = client.releases(repo).find{|r| r.tag_name==tag }
  [client, rel]
end

def upload_to_github(files:)
  $stderr.puts "Add #{files.size} files to github release"

  client, release = repo_release
  old_assets = release.assets

  files.each do |fname|
    if old_asset=old_assets.find{|a| a.name == File.basename(fname) }
      $stderr.puts "Delete old #{old_asset.name}"
      client.delete_release_asset(old_asset.url)
    end

    $stderr.print "Uploading #{fname} (#{File.size(fname)} bytes) ... "
    client.upload_asset(release.url, fname, content_type: CONTENT_TYPE_FOR_EXT[File.extname(fname)])
    $stderr.puts "OK"
  end
end

namespace "upload" do
  desc "aquire lock for upload"
  task "lock" do
    Dir.mktmpdir do |tmpdir|
      my_lockid = ENV['DEPLOY_LOCK']
      fname = File.join(tmpdir, "lock.txt")
      File.write(fname, my_lockid)

      loop do
        client, release = repo_release
        if asset=release.assets.find{|a| a.name == File.basename(fname) }
          # already locked
          their_lockid = asset.label
          break if their_lockid == my_lockid
          $stderr.print "Wait for lock"
          sleep rand(10)
        else
          # try to lock
          begin
            $stderr.print "Uploading #{fname} (#{File.size(fname)} bytes) ... "
            client.upload_asset(release.url, fname,
                                content_type: CONTENT_TYPE_FOR_EXT[File.extname(fname)],
                                label: my_lockid)
          rescue Faraday::ConnectionFailed, Octokit::UnprocessableEntity
          rescue Octokit::ClientError
            # Wait longer due to abuse detection
            sleep 75
          end
        end
      end
    end
  end

  desc "release lock for upload"
  task "unlock" do
    client, release = repo_release
    assets = release.assets
    my_lockid = ENV['DEPLOY_LOCK']
    fname = "lock.txt"

    if asset=assets.find{|a| a.name == File.basename(fname) }
      their_lockid = asset.label
      if their_lockid != my_lockid
        raise "unlocking a foreign lock"
      end

      $stderr.puts "Delete lock file #{asset.name}"
      client.delete_release_asset(asset.url)
    end
  end
end

desc "upload files to github release"
task "upload" do
  files = ARGV[ARGV.index("--")+1 .. -1].reject do |f|
    # Remove unexpanded wildcards and add dummy task to satisfy rake
    !File.exist?(f) && f =~ /[\*\?]/ && task(f)
  end

  upload_to_github(files: files)
end
