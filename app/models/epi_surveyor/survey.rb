module EpiSurveyor
  class Survey < ActiveRecord::Base
    include HTTParty
    base_uri Configuration.instance.epi_surveyor_url    
    extend EpiSurveyor::Dependencies::ClassMethods

    has_many :object_mappings, :dependent => :destroy    
    has_many :import_histories, :dependent => :destroy
    
    attr_accessible :id
    attr_accessor :responses
  
    def test
      Survey.find_by_name('MV-Dist-Info5').sync!
    end
    
    def responses
      @responses ||= SurveyResponse.find_all_by_survey(self)
    end
    
    def questions
      @questions ||= Question.find_all_by_survey(self)
    end
  
    def self.sync_with_epi_surveyor
      response = post('/api/surveys', :body => auth, :headers => headers)
      return [] if response.nil? || response['Surveys'].nil? || response['Surveys']['Survey'].nil?

      surveys = []
      raw_surveys = response['Surveys']['Survey']
      raw_surveys.each do |survey_hash|
        survey = Survey.new
        survey.id = survey_hash['SurveyId']
        survey.name = survey_hash['SurveyName']
        survey.save! unless Survey.exists?(:id => survey.id)
        surveys << survey
      end
      surveys
    end
  
    def sync!
      mappings = object_mappings
      import_histories = responses.collect {|response| response.sync!(mappings)}.select{|import_history| import_history.present?}
      touch(:last_imported_at)
      import_histories
    end

  end
end