namespace :load do
  task :defaults do
    set :fireworks_repo_url, -> { nil }
    set :fireworks_token, -> { nil }
    set :fireworks_server_url, -> { nil }
    set :fireworks_role, -> { :all }
    set :fireworks_slack_hook, -> { nil }
    set :fireworks_v2_url, -> { nil }
  end
end

namespace :fireworks do
  desc 'Notifies about end of deployment'
  task :deployed do
    on roles(fetch(:fireworks_role)) do
      params = commit_details.merge(state: 'finished')
      server_post(params) if fetch(:fireworks_server_url)
      slack_post(params) if fetch(:fireworks_slack_hook)
      fireworks_v2_post("done") if fetch(:fireworks_v2_url)
    end
  end
  desc 'Notifies about start of deployment'
  task :deploying do
    on roles(fetch(:fireworks_role)) do
      params = commit_details.merge(state: 'progress')
      server_post(params) if fetch(:fireworks_server_url)
      fireworks_v2_post("in progress") if fetch(:fireworks_v2_url)
    end
  end

  def default_attributes
    { token: fetch(:fireworks_token), name: fetch(:stage), branch: fetch(:branch),
        username: username }
  end

  def server_post(additional_attributes ={})
    within release_path do
      data = JSON.dump(default_attributes.merge(additional_attributes))
      execute :curl, " -s -S -H \"Content-Type: application/json\" -X POST --data '#{data}' #{fetch(:fireworks_server_url)}/entries"
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

  def fireworks_v2_post(status)
    actor_name = username.match(/\(([^)]+)\)/)[1]

    data = {
      environment: fetch(:stage),
      service: "core",
      status: status,
      actor: actor_name,
      data: {
        branch: fetch(:branch),
        tested: false,
        commit: {
          title: commit_details[:commit],
          url: commit_details[:commit_url],
          description: commit_details[:subject]
        }
      }
    }.to_json

    within release_path do
      execute :curl, "--location '#{fetch(:fireworks_v2_url)}/api/v1/deployments' --header 'Content-Type: application/json' --data '#{data}'"
    end
  end
end

after 'deploy:updating', 'fireworks:deploying'
after 'deploy:finishing', 'fireworks:deployed'
