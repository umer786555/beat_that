enum ReportReason {
  harassment('Harassment or Bullying', 'Violence, threats, hateful behavior'),
  hateSpeech('Hate Speech', 'Content promoting discrimination'),
  selfHarm('Self-Harm or Suicide', 'Concerning content about self-injury'),
  misinformation('Misinformation', 'False or misleading information'),
  spam('Spam or Scam', 'Deceptive or repetitive content'),
  sexual('Sexual Content', 'Inappropriate sexual material'),
  violence('Violent Content', 'Gore, weapons, dangerous acts'),
  copyright('Copyright Violation', 'Unauthorized use of intellectual property'),
  underage('Underage Safety', 'Child exploitation or endangerment'),
  eating('Eating Disorders', 'Content promoting eating disorders'),
  other('Other', 'Something else');

  const ReportReason(this.label, this.description);

  final String label;
  final String description;
}
