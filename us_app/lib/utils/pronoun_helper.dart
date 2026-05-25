class PronounHelper {
  static String subject(String pronoun) {
    switch (pronoun) {
      case 'he': return 'He';
      case 'they': return 'They';
      default: return 'She';
    }
  }

  static String object(String pronoun) {
    switch (pronoun) {
      case 'he': return 'Him';
      case 'they': return 'Them';
      default: return 'Her';
    }
  }

  static String possessive(String pronoun) {
    switch (pronoun) {
      case 'he': return 'His';
      case 'they': return 'Their';
      default: return 'Her';
    }
  }

  static String world(String pronoun) => '${possessive(pronoun)} World';
}
