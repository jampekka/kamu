from haystack import indexes
from parliament.models import Member, Statement, Document
from social.models import Update


class MemberIndex(indexes.SearchIndex, indexes.Indexable):
    text = indexes.CharField(document=True, model_attr='name', use_template=False)
    autosuggest = indexes.EdgeNgramField(model_attr='name')

    def get_updated_field(self):
        return 'last_modified_time'

    def get_model(self):
        return Member

    def index_queryset(self, using=None):
        return self.get_model().objects.current()

    def prepare(self, obj):
        data = super(MemberIndex, self).prepare(obj)
        data['boost'] = 2.0
        return data


class DocumentIndex(indexes.SearchIndex, indexes.Indexable):
    text = indexes.CharField(document=True, use_template=True)
    subject = indexes.CharField(model_attr='subject')
    autosuggest = indexes.EdgeNgramField(model_attr='subject')
    date = indexes.DateField()

    def get_updated_field(self):
        return 'last_modified_time'

    def get_model(self):
        return Document


class StatementIndex(indexes.SearchIndex, indexes.Indexable):
    text = indexes.CharField(document=True, model_attr='text')
    date = indexes.DateField()

    def get_updated_field(self):
        return 'item__plsess__last_modified_time'

    def get_model(self):
        return Statement


class SocialUpdateIndex(indexes.SearchIndex, indexes.Indexable):
    text = indexes.CharField(document=True, model_attr='text')
    date = indexes.DateField(model_attr='created_time')

    def get_updated_field(self):
        return 'last_modified_time'

    def get_model(self):
        return Update

    def index_queryset(self, using=None):
        queryset = Update.objects.filter(text__isnull=False)
        return queryset
