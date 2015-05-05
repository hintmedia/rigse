module React
  module DataHelpers
    # This module expects to be included into a controller, so that view_context resolves
    # to something that provides all the various view helpers.

    private

    def search_material(opts)
      search = Search.new(opts)
      # TODO: This will become a check on 'material_type'
      @investigations       = search.results[Search::InvestigationMaterial] || []
      @investigations_count = @investigations.size
      @activities           = search.results[Search::ActivityMaterial] || []
      @activities_count     = @activities.size
      @form_model = search
    end

    def search_results_data
      return {
        results: [
          {
            type: 'investigations',
            header: view_context.t(:investigation).pluralize.titleize,
            count: @investigations_count,
            materials: materials_data(@investigations),
            pagination: {
              current_page: @investigations.current_page,
              total_pages: @investigations.total_pages,
              start_item: @investigations.offset + 1,
              end_item: @investigations.offset +  @investigations.length,
              total_items: @investigations.total_entries,
              params: {
                type: 'inv'
              }
            }
          },
          {
            type: 'activities',
            header: view_context.t(:activity).pluralize.titleize,
            count: @activities_count,
            materials: materials_data(@activities),
            pagination: {
              current_page: @activities.current_page,
              total_pages: @activities.total_pages,
              start_item: @activities.offset + 1,
              end_item: @activities.offset +  @activities.length,
              total_items: @activities.total_entries,
              params: {
                type: 'act'
              }
            }
          }
        ]
      }
    end

    def materials_data(materials)
      data = []

      materials.each do |material|
        parent_data = nil

        material_count = material.offerings_count
        if material.parent
          material_count = material_count + material.parent.offerings_count

          parent_data = {
            id: material.parent.id,
            type: view_context.t(:investigation),
            name: material.parent.name
          }
        end

        has_activities = material.respond_to?(:activities) && !material.activities.nil?
        has_pretest = material.respond_to?(:has_pretest) && material.has_pretest

        user_data = nil
        if material.user && (!material.user.name.nil?)
          user_data = {
            id: material.user.id,
            name: material.user.name
          }
        end

        mat_data = {
          id: material.id,
          name: material.name,
          description: (current_visitor.portal_teacher && material.description_for_teacher.present? ? view_context.sanitize(material.description_for_teacher) : view_context.sanitize(material.description)),
          class_name_underscored: material.class.name.underscore,
          icon: {
            url: (material.respond_to?(:icon_image) ? material.icon_image : nil),
          },
          java_requirements: material.java_requirements,
          is_official: material.is_official,
          links: links_for_material(material),
          assigned_classes: assigned_clazz_names(material),
          class_count: material_count,
          sensors: view_context.probe_types(material).map { |p| p.name },
          has_activities: has_activities,
          has_pretest: has_pretest,
          activities: material.activities.map{|a| {id: a.id, name: a.name} },
          parent: parent_data,
          user: user_data
        }

        data.push mat_data
      end
      return data
    end

    def links_for_material(material)
      external = false
      if material.is_a? Investigation
        browse_url = browse_investigation_url(material)
      elsif material.is_a? Activity
        browse_url = browse_activity_url(material)
      elsif material.is_a? ExternalActivity
        browse_url = browse_external_activity_url(material)
        external = true
      end

      links = {
        browse: {
          url: browse_url
        }
      }

      if current_visitor.anonymous? or external
        links[:preview] = {
          url: view_context.run_url_for(material,{}),
          text: 'Preview',
          target: '_blank'
        }
      else
        if material.teacher_only?
          links[:preview] = {
            url: view_context.run_url_for(material,{:teacher_mode => true}),
            text: 'Preview',
            target: '_blank'
          }
        else
          links[:preview] = {
            type: 'dropdown',
            text: 'Preview &#9660;',
            expandedText: 'Preview &#9650;',
            url: 'javascript:void(0)',
            className: 'button preview_Button Expand_Collapse_Link',
            options: [
              {
                text: 'As Teacher',
                url: view_context.run_url_for(material, {:teacher_mode => true}),
                target: '_blank',
                className: ''
              },
              {
                text: 'As Student',
                url: view_context.run_url_for(material, {}),
                target: '_blank',
                className: ''
              }
            ]

          }
        end
      end

      if external && material.launch_url
        if current_visitor.has_role?('admin','manager') || (material.author_email == current_visitor.email)
          links[:external_edit] = {
            url: matedit_external_activity_url(material, iFrame: false),
            text: "Edit",
            target: '_blank'
          }
        end
        if current_visitor.has_role?('admin','manager') || (!material.is_locked && current_visitor.has_role?('author')) || material.author_email == current_visitor.email
          links[:external_copy] = {
            url: copy_external_activity_url(material),
            text: "Copy",
            target: '_blank'
          }
        end
        if current_visitor.has_role?('admin')
          links[:external_edit_iframe] = {
            url: matedit_external_activity_url(material, iFrame: true),
            text: "(edit&nbsp;in&nbsp;iframe)",
            target: '_blank'
          }
        end
      end

      if material.respond_to?(:teacher_guide_url) && !material.teacher_guide_url.blank?
        if current_visitor.portal_teacher || current_visitor.has_role?('admin','manager')
          links[:teacher_guide] = {
            text: "Teacher Guide",
            url: material.teacher_guide_url
          }
        end
      end

      if current_visitor.portal_teacher
        links[:assign_material] = {
          text: "Assign to a Class",
          url: "javascript:void(0)",
          onclick: "get_Assign_To_Class_Popup(#{material.id},'#{material.class.to_s}')"
        }
      end

      if current_visitor.has_role?('admin','manager')
        links[:edit] = {
          text: "(portal&nbsp;settings)",
          url: edit_polymorphic_url(material)
        }
      end

      if current_visitor.has_role?('admin')
        links[:assign_collection] = {
          text: "Add to Collection",
          url: "javascript:void(0)",
          onclick: "get_Assign_To_Collection_Popup(#{material.id},'#{material.class.to_s}')"
        }
      end

      return links
    end

    def assigned_clazz_names(material)
      return [] unless current_visitor.portal_teacher
      offerings = current_visitor.portal_teacher.offerings.select{|o| o.runnable == material }
      offering_clazz_names = offerings.sort{|a,b| a.clazz.position <=> b.clazz.position}.map{|o| o.clazz.name}
      return offering_clazz_names
    end
  end
end
