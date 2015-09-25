class Aws::ECS::Client
	class AugmentedContainerInstance
		attr_accessor :container_instance, :ec2_instance
		def initialize(container_instance)
			@container_instance = container_instance
		end

		def method_missing(m, *args, &block)
			@container_instance.send(m, *args, &block)
		end
	end

	class AugmentedTask
		attr_accessor :task, :container_instance, :task_definition

		def initialize(task)
			@task = task
		end

		def method_missing(m, *args, &block)
			@task.send(m, *args, &block)
		end
	end

	def augmented_list_tasks(ec2, **options)
		tasks = self.list_tasks(**options).map do |page|
			return [] if page.task_arns.empty?
			# Empty array is invalid input; shortcut out
			self.describe_tasks(cluster: options[:cluster], tasks: page.task_arns).tasks.map{|t| AugmentedTask.new(t)}
		end.flatten

		tasks.each do |task|
			task.task_definition = self.describe_task_definition(task_definition: task.task_definition_arn).task_definition
		end

		container_instance_arns = tasks.map(&:container_instance_arn).sort.uniq

		container_instances = container_instance_arns.each_slice(100).map do |slice|
			self.describe_container_instances(cluster: options[:cluster], container_instances: slice).container_instances
		end.flatten.map{|ci| AugmentedContainerInstance.new(ci)}

		tasks.each do |task|
			task.container_instance = container_instances.select{|ci| ci.container_instance_arn == task.container_instance_arn}.first
		end

		ec2_instance_ids = container_instances.map(&:ec2_instance_id).sort.uniq
		ec2_instances = ec2.describe_instances(instance_ids: ec2_instance_ids).reservations.map(&:instances).flatten

		container_instances.each do |ci|
			ci.ec2_instance = ec2_instances.select{|instance| instance.instance_id == ci.ec2_instance_id}.first
		end

		tasks
	end
end
