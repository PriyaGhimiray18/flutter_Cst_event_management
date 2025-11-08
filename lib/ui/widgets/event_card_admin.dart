import 'package:flutter/material.dart';

class EventCardAdmin extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget statusChip;
  final VoidCallback? onDetails;
  final VoidCallback? onDecline;
  final VoidCallback? onApprove;
  final VoidCallback? onTap;
  final int? attendees;
  final String? imageUrl;
  final bool isUrgent;

  const EventCardAdmin({
    super.key,
    required this.title,
    required this.subtitle,
    required this.statusChip,
    this.onDetails,
    this.onDecline,
    this.onApprove,
    this.onTap,
    this.attendees,
    this.imageUrl,
    this.isUrgent = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image Section
            if (imageUrl != null)
              Stack(
                children: [
                  Image.network(
                    imageUrl!,
                    height: 160,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      height: 160,
                      color: Colors.grey.shade200,
                      child: Icon(Icons.image, size: 40, color: Colors.grey.shade400),
                    ),
                  ),
                  // Urgent badge
                  if (isUrgent)
                    Positioned(
                      top: 12,
                      left: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.amber,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.warning, color: Colors.white, size: 14),
                            SizedBox(width: 4),
                            Text(
                              'Urgent',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  // Status badge
                  Positioned(
                    top: 12,
                    right: 12,
                    child: statusChip,
                  ),
                ],
              ),
            
            // Content Section
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title and Status Row
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (isUrgent && imageUrl == null)
                        Container(
                          margin: const EdgeInsets.only(right: 8, top: 2),
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade50,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Icon(
                            Icons.warning,
                            color: Colors.amber,
                            size: 16,
                          ),
                        ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1A1A1A),
                                height: 1.2,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              subtitle,
                              style: const TextStyle(
                                fontSize: 14,
                                color: Color(0xFF666666),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (imageUrl == null) statusChip,
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Info Section
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8F9FA),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        if (attendees != null) ...[
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: const Color(0xFF4CAF50).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.people,
                              size: 16,
                              color: Color(0xFF4CAF50),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            '$attendees ${attendees == 1 ? 'participant' : 'participants'}',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1A1A1A),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: onDetails,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: theme.colorScheme.primary,
                            side: BorderSide(color: theme.colorScheme.primary),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: const Icon(Icons.info_outline, size: 18),
                          label: const Text(
                            'Details',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: onDecline,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFF44336),
                            side: const BorderSide(color: Color(0xFFF44336), width: 1.5),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: const Icon(Icons.close, size: 18),
                          label: const Text(
                            'Decline',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: onApprove,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4CAF50),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          icon: const Icon(Icons.check_circle, size: 18),
                          label: const Text(
                            'Approve',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
