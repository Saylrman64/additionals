module Additionals
  module Patches
    module UserPatch
      extend ActiveSupport::Concern

      included do
        include InstanceMethods
      end

      class_methods do
        def with_permission(users, permission, project)
          # Clear cache for debuging performance issue
          # ActiveRecord::Base.connection.clear_query_cache

          # TODO: find a better solution with better performance
          # authors = users.to_a.select { |u| u.allowed_to? permission, project, global: project.nil? }

          role_ids = Role.builtin(false).select { |p| p.permissions.include? permission }
          role_ids.map!(&:id)

          admin_ids = User.visible.active.where(admin: true).ids

          member_scope = Member.joins(:member_roles).active.where(user_id: users.ids).where(member_roles: { role_id: role_ids })

          if project.nil?
            ids = member_scope.map(&:user_id) | admin_ids
            users.where(id: ids)
          else
            member_ids = member_scope.where(project_id: project).map(&:user_id)
            users.where(id: member_ids).or(users.where(id: admin_ids))
          end
        end
      end

      module InstanceMethods
        def issues_assignable?(project = nil)
          scope = Principal.joins(members: :roles)
                           .where(users: { id: id }, roles: { assignable: true })
          scope = scope.where(members: { project_id: project.id }) if project
          scope.exists?
        end
      end
    end
  end
end
