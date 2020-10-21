require 'aws-sdk'
require 'slack-messenger'

module MONITORING
    class SmartArchitecture
        attr_accessor :Access_Key_id, :Secret_Access_Key, :region, :credentials, :messenger, :bucket_policy
        def initialize
            @messenger = Slack::Messenger.new "https://hooks.slack.com/services/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" do 
                defaults channel: "#tech_team",
                username: "NotificationAWSApp"
            end
            @bucket_policy = ''
            @Access_Key_id = 'AKIA2K5ZMRICOQQW6IOO'
            @Secret_Access_Key = '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'
            @region = 'us-east-1'
            @credentials = Aws::Credentials.new(@Access_Key_id, @Secret_Access_Key)
            Aws.config.update(region: @region,
                credentials: @credentials)
        end
        def ElasticBeanstalk
            ebClient = Aws::ElasticBeanstalk::Client.new(region: @region, credentials: @credentials)
            resp = ebClient.describe_environments({
                environment_names:[
                    "Smart-omega",
                    "Smart-alphaDEV"
                ]
            })
            resp.each do |data|
                data['environments'].each do |fdata|
                    puts "Nombre de la aplicacion: #{fdata.application_name}\n\t\tEntorno: #{fdata.environment_name}\n\t\tID: #{fdata.environment_id}\n\t\tURL: #{fdata.endpoint_url}\n\t\tHealth Status: #{fdata.health_status}(#{fdata.health})\n\t\tStatus: #{fdata.status}"
                    if fdata.health_status != "Ok"
                        @messenger.ping "El Estado de los Entornos en ElasticBeanstalk cambio a #{fdata.health_status}"
                    end
                end
            end
        end
        def S3
            s3Client = Aws::S3::Client.new(
                region: @region,
                credentials: @credentials
            )
            resp = s3Client.list_buckets({})
            resp.each do |data|
                data['buckets'].each do |fdata|
                    puts "Viendo las politicas del bucket: #{fdata.name}"
                    s3Policy = s3Client.get_bucket_policy({
                        bucket: fdata.name
                    })
                    raise "The bucket policy does not exist"
                    rescue Aws::S3::Errors::NoSuchBucketPolicy, RuntimeError => e
                        if e
                            puts "Error: #{e.message}"
                        else
                            puts s3Policy.to_h
                        end
                end
            end
        end
        def EC2
            ec2Resource = Aws::EC2::Resource.new(
                region: @region
            )
            ec2Client = Aws::EC2::Client.new(
                region: @region,
                credentials: @credentials
            )
            ec2Resource.instances.each do |instance|
                resp = ec2Client.describe_instances({
                    instance_ids: [
                        "#{instance.id}"
                    ]
                })
                resp['reservations'].each do |data|
                    data['instances'].each do |fdata|
                        puts "Instance_ID: #{fdata.instance_id}\n\t\tInstance_Type: #{fdata.instance_type}\n\t\tInstance_Name: #{fdata.key_name}\n\t\tInstance_State: #{fdata.state['name']}\n\t\tSecurity Group Name: #{fdata.security_groups}"
                        if fdata.state['name'] != 'running'
                            @messenger.ping "La instancia #{fdata.key_name} cambio de estado a #{fdata.state['name']}"
                        end
                    end
                end
            end
        end
        def RDS
            rdsclient = Aws::RDS::Client.new(
                region: @region,
                credentials: @credentials
            )
            resp = rdsclient.describe_db_instances({
                db_instance_identifier: "stxcubes2"
            })
            resp['db_instances'].each do |data|
                puts data
            end
        end
        def CloudWatch
            cloudwatch = Aws::CloudWatch::Client.new(
                region: @region,
                credentials: @credentials
            )
            resp = cloudwatch.get_dashboard({
                dashboard_name: "Elastic"
            })
            metrics = resp.dashboard_body
            puts metrics[21,-1]
        end
    end
end
