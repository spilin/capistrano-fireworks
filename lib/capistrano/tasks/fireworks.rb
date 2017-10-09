namespace :load do
  task :defaults do
    set :fireworks_repo_url, -> { nil }
    set :fireworks_token, -> { nil }
    set :fireworks_server_url, -> { nil }
    set :fireworks_role, -> { :all }
    set :fireworks_slack_hook, -> { nil }
  end
end

namespace :fireworks do
  desc 'Notifies about start of deployment'
  task :deployed do
    on roles(fetch(:fireworks_role)) do
      params = commit_details.merge(state: 'finished')
      server_post(params) if fetch(:fireworks_server_url)
      slack_post(params) if fetch(:fireworks_slack_hook)
    end
  end
  desc 'Notifies about end of deployment'
  task :deploying do
    on roles(fetch(:fireworks_role)) do
      params = commit_details.merge(state: 'progress')
      server_post(params) if fetch(:fireworks_server_url)
    end
  end

  def default_attributes
    { token: fetch(:fireworks_token), name: fetch(:stage), branch: fetch(:branch),
        username: username }
  end

  def server_post(additional_attributes ={})
    within release_path do
      encoded_data = default_attributes.merge(additional_attributes).each_with_object("") do |(key, value), str|
        str << " --data-urlencode \"#{key}=#{value}\""
      end
      execute :curl, "-G -X POST \"#{fetch(:fireworks_server_url)}/entries\"#{encoded_data}"
    end
  end

  def slack_post(additional_attributes ={})
    Capistrano::Fireworks::SlackPost.new(hook_url: fetch(:fireworks_slack_hook), attributes: default_attributes.merge(additional_attributes)).call
  end

  def username
    run_locally { "#{capture(:id, '-u -n')}(#{capture(:git, 'config user.name')})" }
  end

  def commit_details
    within repo_path do
      commit, author, subject = capture(:git, "log -n 1 --format=format:\"%h%n%an%n%s\" #{fetch(:branch)}").split("\n")
      { commit: commit, commit_url: "#{fetch(:fireworks_repo_url)}/commits/#{commit}", author: author, subject: subject }
    end
  end
end

after 'deploy:updating', 'fireworks:deploying'
after 'deploy:finishing', 'fireworks:deployed'
