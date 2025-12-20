class ImageUploadResponse {
  final String userId;
  final String fileId;
  final String fileName;
  final String uploadPresignedUrl;

  ImageUploadResponse({
    required this.userId,
    required this.fileId,
    required this.fileName,
    required this.uploadPresignedUrl,
  });

  factory ImageUploadResponse.fromJson(Map<String, dynamic> json) {
    return ImageUploadResponse(
      userId: json['data']['user_id'] ?? '',
      fileId: json['data']['file_id'] ?? '',
      fileName: json['file_name'] ?? '',
      uploadPresignedUrl: json['data']['upload_presigned_url'] ?? '',
    );
  }
}
