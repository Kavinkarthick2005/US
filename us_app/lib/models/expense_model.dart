

class ExpenseModel {
  final String id;
  final String coupleId;
  final String addedBy;
  final double amount;
  final String category;
  final String description;
  final bool isLoan;
  final String? loanTo;
  final bool isPaid;
  final DateTime spentAt;
  final DateTime createdAt;

  ExpenseModel({
    required this.id,
    required this.coupleId,
    required this.addedBy,
    required this.amount,
    required this.category,
    required this.description,
    required this.isLoan,
    this.loanTo,
    required this.isPaid,
    required this.spentAt,
    required this.createdAt,
  });



  static const catFood         = 'food';
  static const catDate         = 'date';
  static const catTravel       = 'travel';
  static const catGift         = 'gift';
  static const catSubscription = 'subscription';
  static const catOther        = 'other';

  String get emoji {
    switch (category) {
      case catFood:         return '🍕';
      case catDate:         return '💕';
      case catTravel:       return '✈️';
      case catGift:         return '🎁';
      case catSubscription: return '📱';
      default:              return '📝';
    }
  }

  String get label {
    switch (category) {
      case catFood:         return 'Food';
      case catDate:         return 'Date';
      case catTravel:       return 'Travel';
      case catGift:         return 'Gift';
      case catSubscription: return 'Subscription';
      default:              return 'Other';
    }
  }

  factory ExpenseModel.fromJson(Map<String, dynamic> j) => ExpenseModel(
        id:          j['id'] as String,
        coupleId:    j['couple_id'] as String,
        addedBy:     j['added_by'] as String,
        amount:      (j['amount'] as num).toDouble(),
        category:    j['category'] as String,
        description: j['description'] as String? ?? '',
        isLoan:      j['is_loan'] as bool? ?? false,
        loanTo:      j['loan_to'] as String?,
        isPaid:      j['is_paid'] as bool? ?? false,
        spentAt:     DateTime.parse(j['spent_at'] as String).toLocal(),
        createdAt:   DateTime.parse(j['created_at'] as String).toLocal(),
      );

  Map<String, dynamic> toJson() => {
        'id':          id,
        'couple_id':   coupleId,
        'added_by':    addedBy,
        'amount':      amount,
        'category':    category,
        'description': description,
        'is_loan':     isLoan,
        if (loanTo != null) 'loan_to': loanTo,
        'is_paid':     isPaid,
        'spent_at':    spentAt.toUtc().toIso8601String(),
        'created_at':  createdAt.toUtc().toIso8601String(),
      };
}
