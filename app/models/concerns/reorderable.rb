module Reorderable
  extend ActiveSupport::Concern

  class_methods do
    # Rewrites `column` to a contiguous 1..N sequence matching ordered_ids,
    # within `scope`. ordered_ids must be the complete set of the scope's ids.
    # Two-phase (offset all rows above the current max, then set 1..N) so that
    # models with a UNIQUE index on the position column never collide
    # mid-transaction. Raises ActiveRecord::RecordNotFound if any id is missing
    # from the scope or ordered_ids contains duplicates. Atomic.
    def reorder_within!(scope, ordered_ids, column: :position)
      ids = Array(ordered_ids).map(&:to_i)
      records = scope.where(id: ids).index_by(&:id)
      raise ActiveRecord::RecordNotFound unless records.length == ids.length

      transaction do
        offset = (scope.maximum(column) || 0) + 1
        ids.each_with_index { |id, index| records.fetch(id).update!(column => offset + index) }
        ids.each_with_index { |id, index| records.fetch(id).update!(column => index + 1) }
      end
    end
  end
end
