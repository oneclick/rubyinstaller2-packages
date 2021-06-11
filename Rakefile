CONTENT_TYPE_FOR_EXT = {
  ".sig" => "application/pgp-signature",
  ".db" => "application/zstd",
  ".files" => "application/zstd",
  ".zst" => "application/zstd",
}

def upload_to_github(tag:, repo:, token: nil, files:)
  require "octokit"

  client = Octokit::Client.new(access_token: token)
  release = client.releases(repo).find{|r| r.tag_name==tag }
  $stderr.puts "Add #{files.size} files to github release #{tag}"

  old_assets = client.release_assets(release.url)

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

desc "upload files to github release"
task "upload" do
  files = ARGV[ARGV.index("--")+1 .. -1]

  upload_to_github(
    tag: ENV['DEPLOY_TAG'],
    repo: ENV['DEPLOY_REPO_NAME'],
    token: ENV['DEPLOY_TOKEN'],
    files: files
  )
end
