package com.example.bamm;

interface IFileService {
    boolean fileExists(String path);
    byte[] readFile(String path);
    boolean writeFile(String path, in byte[] data);
    boolean copyFile(String sourcePath, String destPath);
    boolean deleteFile(String path);
    List<String> listFiles(String directoryPath);
    List<String> listFilesPage(String directoryPath, int offset, int limit);
    boolean createDirectory(String path);
    boolean isDirectory(String path);
    long getFileSize(String path);
    String getFileMd5(String path);
    void destroy();
    void exit();
}
