class API::V1::MaterialsCollectionsController < API::APIController
  include Materials::DataHelpers

  # GET /api/v1/materials_collections/data?<params>id=:id OR GET /api/v1/materials_collections/data?id[]=:id1&id[]=:id2
  # Always returns ARRAY of collections (even if single collection is returned).
  # Supported params:
  #   - ?id=:id or ?id[]=:id1&id[]=:id2 - returns collections with given IDs
  #   - ?own_external_activities=true - returns 'fake' collection with own external activities
  #   - ?own_activities=true - returns 'fake' collection with own activities
  #   - ?own_investigations=true - returns 'fake' collection with own investigations
  #   - ?own_materials=true - returns 'fake' collection with own materials (sum of all categories above)
  # Note that materials are filtered by cohorts of current visitor!
  def data
    # Preserver order of collections provided by client!
    collection_by_id = MaterialsCollection.where(id: params[:id]).index_by { |mc| mc.id.to_s }
    collections = Array(params[:id]).map do |id|
      col = collection_by_id[id]
      materials_collection_data(col.name, col.materials(allowed_cohorts))
    end
    render json: collections
  end

  private

  def allowed_cohorts
    # Empty array means that only materials that are not assigned to any cohorts will be displayed.
    current_visitor.portal_teacher ? current_visitor.portal_teacher.cohort_list : []
  end

  def materials_collection_data(name, materials)
    {
        name: name,
        materials: materials_data(materials)
    }
  end
end
