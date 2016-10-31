qs = Queries::PolicyAggregationPipeline.new

qs.filter_to_individual.filter_to_active.with_effective_date({"$gt" => Date.new(2016,12,31)}).eliminate_family_duplicates

enroll_pol_ids = []

qs.evaluate.each do |r|
  if r['aasm_state'] == "auto_renewing"
    enroll_pol_ids << r['hbx_id']
  end
end

glue_list = File.read("all_glue_policies.txt").split("\n").map(&:strip)

missing = (enroll_pol_ids - glue_list)

missing.each do |m|
    puts m
end
